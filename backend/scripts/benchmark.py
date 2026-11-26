"""Benchmark faster-whisper models (base, small, medium) on real audio.

Supports comparing:
- Original audio normalized to 16 kHz mono PCM WAV
- App-quality audio transcoded first to AAC 16 kHz mono 32 kbps, then normalized
- Models: base, small, medium (skips any model that fails to load)
- Languages: forced en, forced ms, forced id, and auto-detect (auto)
- Per-30s-window language change tracking via model.detect_language()
- Optional accuracy scoring (--reference <file.txt>) using jiwer WER & CER
"""

from __future__ import annotations

import argparse
import gc
import json
import os
import re
import shutil
import subprocess
import sys
import time
import wave
from dataclasses import asdict, dataclass
from pathlib import Path

MODEL_SIZES = ("base", "small", "medium")
LANGUAGE_SETTINGS: tuple[tuple[str, str | None], ...] = (
    ("en", "en"),
    ("ms", "ms"),
    ("id", "id"),
    ("auto", None),
)
UNSCORED_LABEL = "UNSCORED, do not trust"


@dataclass
class GpuInfo:
    cuda_device_count: int
    rocm_devices: list[str]
    selected_device: str
    selected_compute_type: str
    note: str


@dataclass
class ClipSpec:
    name: str
    source_path: Path
    start_sec: float | None = None
    duration_sec: float | None = None


@dataclass
class BenchmarkRow:
    clip: str
    quality: str
    model: str
    language_setting: str
    status: str
    processing_sec: float | None
    audio_duration_sec: float
    rtf: float | None
    est_60min_sec: float | None
    detected_language: str | None
    detected_prob: float | None
    language_changes_count: int
    language_changes: list[dict]
    wer: float | None
    cer: float | None
    scoring_status: str
    avg_logprob: float | None
    compression_ratio_mean: float | None
    preview_500: str
    output_file: str | None
    error: str | None = None


def detect_gpu() -> GpuInfo:
    """Detect CUDA or ROCm GPUs and pick the ctranslate2 compute device."""
    cuda_count = 0
    try:
        import ctranslate2

        cuda_count = int(ctranslate2.get_cuda_device_count())
    except Exception:
        cuda_count = 0

    rocm_devices: list[str] = []
    rocm_smi = shutil.which("rocm-smi")
    if rocm_smi:
        try:
            res = subprocess.run(
                [rocm_smi, "--showproductname"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            for line in res.stdout.splitlines():
                if any(k in line for k in ("Card Model", "Card SKU", "GFX Version")):
                    rocm_devices.append(line.strip())
        except Exception:
            pass

    if cuda_count > 0:
        return GpuInfo(
            cuda_device_count=cuda_count,
            rocm_devices=rocm_devices,
            selected_device="cuda",
            selected_compute_type="float16",
            note=f"Usable CUDA GPU detected ({cuda_count} device(s)).",
        )

    if rocm_devices:
        return GpuInfo(
            cuda_device_count=0,
            rocm_devices=rocm_devices,
            selected_device="cpu",
            selected_compute_type="int8",
            note=(
                "AMD ROCm GPU detected, but standard PyPI ctranslate2/faster-whisper "
                "wheels only accelerate NVIDIA CUDA and CPU. Falling back to CPU (int8)."
            ),
        )

    return GpuInfo(
        cuda_device_count=0,
        rocm_devices=[],
        selected_device="cpu",
        selected_compute_type="int8",
        note="No CUDA or ROCm GPU detected; using CPU (compute_type=int8).",
    )


def wav_duration_sec(wav_path: Path) -> float:
    with wave.open(str(wav_path), "rb") as wf:
        frames = wf.getnframes()
        rate = wf.getframerate()
        return frames / float(rate) if rate > 0 else 0.0


def _run_ffmpeg(cmd: list[str], step_label: str) -> None:
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"ffmpeg ({step_label}) failed: {res.stderr.strip()}")


def prepare_wav_versions(
    clip: ClipSpec,
    clips_dir: Path,
    versions: tuple[str, ...],
) -> dict[str, tuple[Path, float]]:
    """Create original (16kHz mono WAV) and/or app-quality (AAC 16kHz mono 32kbps -> WAV)."""
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("ffmpeg not found on PATH.")

    clips_dir.mkdir(parents=True, exist_ok=True)
    trim_args: list[str] = []
    if clip.start_sec is not None:
        trim_args.extend(["-ss", str(clip.start_sec)])
    if clip.duration_sec is not None:
        trim_args.extend(["-t", str(clip.duration_sec)])

    prepared: dict[str, tuple[Path, float]] = {}

    if "original" in versions:
        orig_wav = clips_dir / f"{clip.name}_original.wav"
        _run_ffmpeg(
            [
                ffmpeg,
                "-y",
                "-hide_banner",
                "-loglevel",
                "error",
                "-i",
                str(clip.source_path),
                *trim_args,
                "-ar",
                "16000",
                "-ac",
                "1",
                "-c:a",
                "pcm_s16le",
                str(orig_wav),
            ],
            f"{clip.name} original",
        )
        dur = wav_duration_sec(orig_wav)
        if dur <= 0:
            raise RuntimeError(f"{orig_wav} has zero duration.")
        prepared["original"] = (orig_wav, dur)

    if "app-quality" in versions:
        app_m4a = clips_dir / f"{clip.name}_app.m4a"
        app_wav = clips_dir / f"{clip.name}_app.wav"
        _run_ffmpeg(
            [
                ffmpeg,
                "-y",
                "-hide_banner",
                "-loglevel",
                "error",
                "-i",
                str(clip.source_path),
                *trim_args,
                "-ar",
                "16000",
                "-ac",
                "1",
                "-c:a",
                "aac",
                "-b:a",
                "32k",
                str(app_m4a),
            ],
            f"{clip.name} app-quality AAC encode",
        )
        _run_ffmpeg(
            [
                ffmpeg,
                "-y",
                "-hide_banner",
                "-loglevel",
                "error",
                "-i",
                str(app_m4a),
                "-ar",
                "16000",
                "-ac",
                "1",
                "-c:a",
                "pcm_s16le",
                str(app_wav),
            ],
            f"{clip.name} app-quality normalize",
        )
        dur = wav_duration_sec(app_wav)
        if dur <= 0:
            raise RuntimeError(f"{app_wav} has zero duration.")
        prepared["app-quality"] = (app_wav, dur)

    return prepared


def detect_language_timeline(
    model,
    wav_path: Path,
    window_sec: float = 30.0,
) -> tuple[list[dict], list[dict]]:
    """Detect language across 30s windows to locate language-switch boundaries."""
    from faster_whisper import decode_audio

    audio = decode_audio(str(wav_path), sampling_rate=16000)
    win_samples = int(window_sec * 16000)
    min_tail_samples = 16000

    windows: list[dict] = []
    changes: list[dict] = []
    prev_lang: str | None = None

    for start_idx in range(0, len(audio), win_samples):
        chunk = audio[start_idx : start_idx + win_samples]
        if len(chunk) < min_tail_samples and start_idx > 0:
            continue
        end_idx = min(len(audio), start_idx + len(chunk))
        start_s = round(start_idx / 16000.0, 2)
        end_s = round(end_idx / 16000.0, 2)
        lang, prob, _ = model.detect_language(audio=chunk)
        windows.append(
            {
                "start_sec": start_s,
                "end_sec": end_s,
                "language": lang,
                "probability": round(float(prob), 4),
            }
        )
        if prev_lang is not None and lang != prev_lang:
            changes.append(
                {
                    "at_sec": start_s,
                    "end_sec": end_s,
                    "from": prev_lang,
                    "to": lang,
                    "to_probability": round(float(prob), 4),
                }
            )
        prev_lang = lang

    return windows, changes


_REF_TIMESTAMP_RE = re.compile(r"\[\d{1,4}:\d{2}(?::\d{2})?(?:\.\d+)?\]")


def clean_reference_text(raw_text: str) -> str:
    """Strip `# ...` comment lines and `[mm:ss]` timestamps from reference text."""
    lines: list[str] = []
    for line in raw_text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        cleaned_line = re.sub(r"\s+", " ", _REF_TIMESTAMP_RE.sub("", stripped)).strip()
        if cleaned_line:
            lines.append(cleaned_line)
    return " ".join(lines)


def compute_wer_cer(reference_text: str, hypothesis_text: str) -> tuple[float, float]:
    """Compute WER and CER with jiwer after case & punctuation normalization."""
    import jiwer

    cleaned_ref = clean_reference_text(reference_text)
    base_transforms = [
        jiwer.ToLowerCase(),
        jiwer.RemovePunctuation(),
        jiwer.RemoveMultipleSpaces(),
        jiwer.Strip(),
    ]
    word_norm = jiwer.Compose([*base_transforms, jiwer.ReduceToListOfListOfWords()])
    char_norm = jiwer.Compose([*base_transforms, jiwer.ReduceToListOfListOfChars()])

    wer_val = float(
        jiwer.wer(
            cleaned_ref,
            hypothesis_text,
            reference_transform=word_norm,
            hypothesis_transform=word_norm,
        )
    )
    cer_val = float(
        jiwer.cer(
            cleaned_ref,
            hypothesis_text,
            reference_transform=char_norm,
            hypothesis_transform=char_norm,
        )
    )
    return wer_val, cer_val


def format_duration(seconds: float | None) -> str:
    if seconds is None:
        return "-"
    total = int(round(seconds))
    mins, secs = divmod(total, 60)
    hours, mins = divmod(mins, 60)
    if hours > 0:
        return f"{hours}h {mins:02d}m {secs:02d}s"
    return f"{mins}m {secs:02d}s"


def extract_text_for_range(
    segments: list[dict],
    ref_start: float | None,
    ref_end: float | None,
) -> str:
    parts: list[str] = []
    for seg in segments:
        s0 = float(seg["start"])
        s1 = float(seg["end"])
        if ref_start is not None and s1 <= ref_start:
            continue
        if ref_end is not None and s0 >= ref_end:
            continue
        txt = seg["text"].strip()
        if txt:
            parts.append(txt)
    return " ".join(parts)


def run_benchmark(
    clips: list[ClipSpec],
    out_dir: Path,
    cpu_threads: int,
    models: tuple[str, ...],
    languages: tuple[tuple[str, str | None], ...],
    versions: tuple[str, ...],
    reference_text: str | None = None,
    ref_clip: str | None = None,
    ref_start: float | None = None,
    ref_end: float | None = None,
    resume: bool = False,
) -> tuple[GpuInfo, list[BenchmarkRow]]:
    from faster_whisper import WhisperModel

    out_dir.mkdir(parents=True, exist_ok=True)
    clips_dir = out_dir / "prepared_clips"
    gpu_info = detect_gpu()

    print("=== Hardware / Device Report ===")
    print(f"CUDA devices : {gpu_info.cuda_device_count}")
    if gpu_info.rocm_devices:
        print(f"ROCm GPU info: {' | '.join(gpu_info.rocm_devices)}")
    else:
        print("ROCm GPU info: none")
    print(
        f"Using device : {gpu_info.selected_device} "
        f"(compute_type={gpu_info.selected_compute_type}, cpu_threads={cpu_threads})"
    )
    print(f"Note         : {gpu_info.note}")
    print(
        f"Accuracy     : {'SCORED against --reference' if reference_text is not None else UNSCORED_LABEL}\n"
    )

    prepared_clips: dict[str, dict[str, tuple[Path, float]]] = {}
    for clip in clips:
        print(f"Preparing clip '{clip.name}' from {clip.source_path}...")
        prepared_clips[clip.name] = prepare_wav_versions(clip, clips_dir, versions)
        for ver_name, (wav_p, dur) in prepared_clips[clip.name].items():
            print(f"  {ver_name:<11}: {wav_p.name} ({dur:.2f}s / {format_duration(dur)})")
    print()

    rows: list[BenchmarkRow] = []
    summary_path = out_dir / "benchmark_summary.json"
    existing_ok: dict[tuple[str, str, str, str], BenchmarkRow] = {}
    if resume and summary_path.is_file():
        try:
            prev_data = json.loads(summary_path.read_text(encoding="utf-8"))
            for item in prev_data.get("results", []):
                prev_row = BenchmarkRow(**item)
                if (
                    prev_row.status == "ok"
                    and prev_row.output_file
                    and Path(prev_row.output_file).is_file()
                ):
                    key = (
                        prev_row.clip,
                        prev_row.quality,
                        prev_row.model,
                        prev_row.language_setting,
                    )
                    existing_ok[key] = prev_row
            if existing_ok:
                print(f"Resuming: found {len(existing_ok)} completed row(s) in {summary_path}\n")
        except Exception as exc:
            print(f"Warning: could not load previous summary for --resume ({exc})\n")

    def write_summary() -> None:
        summary_path.write_text(
            json.dumps(
                {
                    "scoring_status": (
                        "SCORED" if reference_text is not None else UNSCORED_LABEL
                    ),
                    "reference_clip": ref_clip,
                    "reference_range_sec": [ref_start, ref_end],
                    "gpu": asdict(gpu_info),
                    "results": [asdict(r) for r in rows],
                },
                indent=2,
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )

    for model_size in models:
        pending_for_model = any(
            (clip.name, ver_name, model_size, lang_label) not in existing_ok
            for clip in clips
            for ver_name in prepared_clips[clip.name]
            for lang_label, _ in languages
        )
        if not pending_for_model:
            for clip in clips:
                for ver_name in prepared_clips[clip.name]:
                    for lang_label, _ in languages:
                        rows.append(
                            existing_ok[(clip.name, ver_name, model_size, lang_label)]
                        )
            print(f"=== Skipping model '{model_size}' (all rows completed via --resume) ===\n")
            write_summary()
            continue

        print(f"=== Loading model '{model_size}' ===")
        t_load = time.perf_counter()
        try:
            model = WhisperModel(
                model_size,
                device=gpu_info.selected_device,
                compute_type=gpu_info.selected_compute_type,
                cpu_threads=cpu_threads,
            )
            print(f"Loaded '{model_size}' in {time.perf_counter() - t_load:.2f}s\n")
        except Exception as exc:
            err = str(exc)
            print(f"Skipping '{model_size}': failed to load ({err})\n")
            for clip in clips:
                for ver_name, (_, dur) in prepared_clips[clip.name].items():
                    for lang_label, _ in languages:
                        rows.append(
                            BenchmarkRow(
                                clip=clip.name,
                                quality=ver_name,
                                model=model_size,
                                language_setting=lang_label,
                                status="skipped",
                                processing_sec=None,
                                audio_duration_sec=dur,
                                rtf=None,
                                est_60min_sec=None,
                                detected_language=None,
                                detected_prob=None,
                                language_changes_count=0,
                                language_changes=[],
                                wer=None,
                                cer=None,
                                scoring_status=UNSCORED_LABEL
                                if reference_text is None
                                else "SCORED",
                                avg_logprob=None,
                                compression_ratio_mean=None,
                                preview_500="",
                                output_file=None,
                                error=err,
                            )
                        )
            write_summary()
            continue

        for clip in clips:
            for ver_name, (wav_path, duration_sec) in prepared_clips[clip.name].items():
                print(
                    f"--- [{clip.name} | {ver_name} | {model_size}] scanning 30s language windows ---"
                )
                windows, changes = detect_language_timeline(model, wav_path)
                if windows:
                    win_str = ", ".join(
                        f"{w['start_sec']:.0f}-{w['end_sec']:.0f}s:{w['language']}({w['probability']:.2f})"
                        for w in windows
                    )
                    print(f"  30s windows: {win_str}")
                if changes:
                    chg_str = "; ".join(
                        f"@{c['at_sec']:.0f}s {c['from']}->{c['to']}({c['to_probability']:.2f})"
                        for c in changes
                    )
                    print(f"  Language switches ({len(changes)}): {chg_str}")
                else:
                    print("  Language switches (0): none across 30s windows")

                for lang_label, lang_arg in languages:
                    row_key = (clip.name, ver_name, model_size, lang_label)
                    if row_key in existing_ok:
                        print(
                            f"  Skipping cached {row_key}",
                            flush=True,
                        )
                        rows.append(existing_ok[row_key])
                        write_summary()
                        continue
                    print(
                        f"  Transcribing clip={clip.name} quality={ver_name} "
                        f"model={model_size} lang={lang_label}...",
                        flush=True,
                    )
                    t0 = time.perf_counter()
                    try:
                        segments_iter, info = model.transcribe(
                            str(wav_path),
                            language=lang_arg,
                            vad_filter=True,
                        )
                        seg_dicts: list[dict] = []
                        for seg in segments_iter:
                            seg_dicts.append(
                                {
                                    "start": round(float(seg.start), 2),
                                    "end": round(float(seg.end), 2),
                                    "text": seg.text,
                                    "avg_logprob": round(float(seg.avg_logprob), 4),
                                    "compression_ratio": round(
                                        float(seg.compression_ratio), 4
                                    ),
                                    "no_speech_prob": round(
                                        float(seg.no_speech_prob), 4
                                    ),
                                }
                            )
                        elapsed = time.perf_counter() - t0
                        full_text = " ".join(
                            s["text"].strip() for s in seg_dicts if s["text"].strip()
                        )
                        rtf = elapsed / duration_sec
                        est_60m = rtf * 3600.0
                        preview = full_text[:500]
                        avg_lp = (
                            sum(s["avg_logprob"] for s in seg_dicts) / len(seg_dicts)
                            if seg_dicts
                            else None
                        )
                        comp_mean = (
                            sum(s["compression_ratio"] for s in seg_dicts)
                            / len(seg_dicts)
                            if seg_dicts
                            else None
                        )

                        wer_val: float | None = None
                        cer_val: float | None = None
                        row_scoring = UNSCORED_LABEL
                        if reference_text is not None and (
                            ref_clip is None or ref_clip == clip.name
                        ):
                            hyp = extract_text_for_range(seg_dicts, ref_start, ref_end)
                            wer_val, cer_val = compute_wer_cer(reference_text, hyp)
                            row_scoring = "SCORED"

                        stem = f"{clip.name}_{ver_name}_{model_size}_{lang_label}"
                        out_txt = out_dir / f"{stem}.txt"
                        out_seg_json = out_dir / f"{stem}_segments.json"
                        top5_probs = [
                            (lang, round(float(prob), 4))
                            for lang, prob in (info.all_language_probs or [])[:5]
                        ]
                        timestamped_lines = [
                            f"[{s['start']:07.2f} -> {s['end']:07.2f}] {s['text'].strip()}"
                            for s in seg_dicts
                        ]
                        out_txt.write_text(
                            f"scoring_status={row_scoring}\n"
                            f"clip={clip.name} quality={ver_name} model={model_size} "
                            f"language_setting={lang_label} "
                            f"detected_language={info.language} "
                            f"prob={info.language_probability:.4f} "
                            f"audio_sec={duration_sec:.2f} proc_sec={elapsed:.2f} "
                            f"rtf={rtf:.4f} est_60min={format_duration(est_60m)} "
                            f"wer={f'{wer_val:.4f}' if wer_val is not None else 'SKIPPED'} "
                            f"cer={f'{cer_val:.4f}' if cer_val is not None else 'SKIPPED'}\n"
                            f"30s_language_windows={json.dumps(windows)}\n"
                            f"30s_language_switches={json.dumps(changes)}\n"
                            f"top5_language_probs={json.dumps(top5_probs)}\n\n"
                            + "\n".join(timestamped_lines)
                            + "\n\n--- PLAIN TRANSCRIPT ---\n"
                            + full_text
                            + "\n",
                            encoding="utf-8",
                        )
                        out_seg_json.write_text(
                            json.dumps(
                                {
                                    "clip": clip.name,
                                    "quality": ver_name,
                                    "model": model_size,
                                    "language_setting": lang_label,
                                    "detected_language": info.language,
                                    "detected_prob": round(
                                        float(info.language_probability), 4
                                    ),
                                    "language_windows_30s": windows,
                                    "language_switches_30s": changes,
                                    "top5_language_probs": top5_probs,
                                    "segments": seg_dicts,
                                },
                                indent=2,
                                ensure_ascii=False,
                            ),
                            encoding="utf-8",
                        )

                        wer_disp = (
                            f"wer={wer_val:.2%} cer={cer_val:.2%}"
                            if wer_val is not None and cer_val is not None
                            else UNSCORED_LABEL
                        )
                        print(
                            f"    done: time={elapsed:.2f}s rtf={rtf:.3f}x "
                            f"est60m={format_duration(est_60m)} "
                            f"detected={info.language}({info.language_probability:.2f}) "
                            f"[{wer_disp}]",
                            flush=True,
                        )
                        print(f"    preview[0:500]: {preview!r}", flush=True)

                        rows.append(
                            BenchmarkRow(
                                clip=clip.name,
                                quality=ver_name,
                                model=model_size,
                                language_setting=lang_label,
                                status="ok",
                                processing_sec=round(elapsed, 3),
                                audio_duration_sec=round(duration_sec, 3),
                                rtf=round(rtf, 4),
                                est_60min_sec=round(est_60m, 1),
                                detected_language=info.language,
                                detected_prob=round(
                                    float(info.language_probability), 4
                                ),
                                language_changes_count=len(changes),
                                language_changes=changes,
                                wer=round(wer_val, 4) if wer_val is not None else None,
                                cer=round(cer_val, 4) if cer_val is not None else None,
                                scoring_status=row_scoring,
                                avg_logprob=round(avg_lp, 4)
                                if avg_lp is not None
                                else None,
                                compression_ratio_mean=round(comp_mean, 4)
                                if comp_mean is not None
                                else None,
                                preview_500=preview,
                                output_file=str(out_txt),
                            )
                        )
                    except Exception as exc:
                        err = str(exc)
                        print(f"    FAILED: {err}", flush=True)
                        rows.append(
                            BenchmarkRow(
                                clip=clip.name,
                                quality=ver_name,
                                model=model_size,
                                language_setting=lang_label,
                                status="error",
                                processing_sec=None,
                                audio_duration_sec=duration_sec,
                                rtf=None,
                                est_60min_sec=None,
                                detected_language=None,
                                detected_prob=None,
                                language_changes_count=len(changes),
                                language_changes=changes,
                                wer=None,
                                cer=None,
                                scoring_status=UNSCORED_LABEL
                                if reference_text is None
                                else "SCORED",
                                avg_logprob=None,
                                compression_ratio_mean=None,
                                preview_500="",
                                output_file=None,
                                error=err,
                            )
                        )
                    write_summary()

        del model
        gc.collect()

    print(f"\nSaved detailed outputs to: {out_dir}")
    print(f"Summary JSON: {summary_path}\n")
    return gpu_info, rows


def print_summary_table(rows: list[BenchmarkRow], has_reference: bool) -> None:
    banner = (
        "=== Benchmark Results Table (SCORED against --reference) ==="
        if has_reference
        else f"=== Benchmark Results Table [{UNSCORED_LABEL}] ==="
    )
    print(banner)
    header = (
        f"{'Clip':<11} {'Quality':<11} {'Model':<7} {'Lang':<5} {'Proc(s)':>8} "
        f"{'RTF':>7} {'Est 60m':>10} {'WER':>10} {'CER':>8} {'Detected':<11} {'Sw':>3}"
    )
    print(header)
    print("-" * len(header))
    for r in rows:
        proc = f"{r.processing_sec:.2f}" if r.processing_sec is not None else "-"
        rtf = f"{r.rtf:.3f}x" if r.rtf is not None else "-"
        est = format_duration(r.est_60min_sec)
        wer = f"{r.wer:.2%}" if r.wer is not None else "UNSCORED"
        cer = f"{r.cer:.2%}" if r.cer is not None else "SKIPPED"
        det = (
            f"{r.detected_language}({r.detected_prob:.2f})"
            if r.detected_language and r.detected_prob is not None
            else "-"
        )
        print(
            f"{r.clip:<11} {r.quality:<11} {r.model:<7} {r.language_setting:<5} {proc:>8} "
            f"{rtf:>7} {est:>10} {wer:>10} {cer:>8} {det:<11} {r.language_changes_count:>3}"
        )


def parse_clip_arg(spec: str) -> ClipSpec:
    """Parse NAME=PATH[@START:DURATION] clip specification."""
    if "=" not in spec:
        raise argparse.ArgumentTypeError(
            f"Invalid --clip '{spec}': expected NAME=PATH[@START:DURATION]"
        )
    name, rest = spec.split("=", 1)
    start_sec: float | None = None
    dur_sec: float | None = None
    if "@" in rest:
        path_str, time_part = rest.rsplit("@", 1)
        if ":" in time_part:
            s_str, d_str = time_part.split(":", 1)
            start_sec = float(s_str) if s_str else None
            dur_sec = float(d_str) if d_str else None
        else:
            start_sec = float(time_part)
    else:
        path_str = rest

    p = Path(path_str).expanduser().resolve()
    if not p.is_file():
        raise argparse.ArgumentTypeError(f"Audio file not found for clip '{name}': {p}")
    return ClipSpec(name=name, source_path=p, start_sec=start_sec, duration_sec=dur_sec)


def score_existing_summary(
    summary_json: Path,
    reference_text: str,
    ref_clip: str | None,
    ref_start: float | None,
    ref_end: float | None,
) -> int:
    data = json.loads(summary_json.read_text(encoding="utf-8"))
    rows: list[BenchmarkRow] = []
    for item in data["results"]:
        row = BenchmarkRow(**item)
        if row.status == "ok" and row.output_file and (
            ref_clip is None or row.clip == ref_clip
        ):
            seg_path = Path(row.output_file).with_name(
                Path(row.output_file).stem + "_segments.json"
            )
            if seg_path.is_file():
                seg_data = json.loads(seg_path.read_text(encoding="utf-8"))
                hyp = extract_text_for_range(seg_data["segments"], ref_start, ref_end)
            else:
                hyp = row.preview_500
            wer_val, cer_val = compute_wer_cer(reference_text, hyp)
            row.wer = round(wer_val, 4)
            row.cer = round(cer_val, 4)
            row.scoring_status = "SCORED"
        rows.append(row)

    data["scoring_status"] = "SCORED"
    data["reference_clip"] = ref_clip
    data["reference_range_sec"] = [ref_start, ref_end]
    rows.sort(
        key=lambda r: (
            1 if r.wer is None else 0,
            r.wer if r.wer is not None else float("inf"),
            r.cer if r.cer is not None else float("inf"),
            r.rtf if r.rtf is not None else float("inf"),
        )
    )
    data["results"] = [asdict(r) for r in rows]
    summary_json.write_text(
        json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print_summary_table(rows, has_reference=True)
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[2]
    default_out = repo_root / "backend" / "benchmark_out"
    parser = argparse.ArgumentParser(
        description="Benchmark faster-whisper base/small/medium across en/ms/id/auto and original vs app-quality."
    )
    parser.add_argument(
        "audio_file",
        nargs="?",
        type=Path,
        help="Optional single audio file (if not using --clip NAME=PATH).",
    )
    parser.add_argument(
        "--clip",
        action="append",
        default=[],
        help="Repeatable clip spec: NAME=PATH[@START_SEC:DURATION_SEC].",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=default_out,
        help=f"Output folder (default: {default_out}).",
    )
    parser.add_argument(
        "--cpu-threads",
        type=int,
        default=min(6, os.cpu_count() or 4),
        help="CPU worker threads for CTranslate2 when running on CPU.",
    )
    parser.add_argument(
        "--models",
        nargs="+",
        default=list(MODEL_SIZES),
        help="Whisper models to test (default: base small medium).",
    )
    parser.add_argument(
        "--versions",
        nargs="+",
        choices=("original", "app-quality"),
        default=["original", "app-quality"],
        help="Audio quality versions to benchmark (default: both original and app-quality).",
    )
    parser.add_argument(
        "--reference",
        type=Path,
        default=None,
        help="Optional reference transcript .txt file to score WER/CER with jiwer.",
    )
    parser.add_argument(
        "--ref-clip",
        type=str,
        default=None,
        help="Clip name matching --reference when benchmarking multiple clips.",
    )
    parser.add_argument(
        "--ref-start",
        type=float,
        default=None,
        help="Optional start timestamp (seconds within clip) covered by --reference.",
    )
    parser.add_argument(
        "--ref-end",
        type=float,
        default=None,
        help="Optional end timestamp (seconds within clip) covered by --reference.",
    )
    parser.add_argument(
        "--score-summary",
        type=Path,
        default=None,
        help="Score an existing benchmark_summary.json against --reference without re-transcribing.",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Skip (clip, quality, model, language) rows already marked ok in benchmark_summary.json.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    reference_text: str | None = None
    if args.reference is not None:
        ref_path = args.reference.expanduser().resolve()
        if not ref_path.is_file():
            print(f"Error: reference file not found: {ref_path}", file=sys.stderr)
            return 2
        reference_text = clean_reference_text(ref_path.read_text(encoding="utf-8"))
        if not reference_text:
            print(f"Error: reference file is empty: {ref_path}", file=sys.stderr)
            return 2

    if args.score_summary is not None:
        if reference_text is None:
            print(
                "Error: --score-summary requires --reference <file.txt>",
                file=sys.stderr,
            )
            return 2
        return score_existing_summary(
            args.score_summary.expanduser().resolve(),
            reference_text,
            args.ref_clip,
            args.ref_start,
            args.ref_end,
        )

    clips: list[ClipSpec] = [parse_clip_arg(c) for c in args.clip]
    if args.audio_file is not None:
        audio_path = args.audio_file.expanduser().resolve()
        if not audio_path.is_file():
            print(f"Error: audio file not found: {audio_path}", file=sys.stderr)
            return 2
        clips.append(
            ClipSpec(name=audio_path.stem.replace(" ", "_"), source_path=audio_path)
        )

    if not clips:
        print("Error: supply an audio_file or at least one --clip NAME=PATH.", file=sys.stderr)
        return 2

    _, rows = run_benchmark(
        clips=clips,
        out_dir=args.out_dir.expanduser().resolve(),
        cpu_threads=max(1, args.cpu_threads),
        models=tuple(args.models),
        languages=LANGUAGE_SETTINGS,
        versions=tuple(args.versions),
        reference_text=reference_text,
        ref_clip=args.ref_clip,
        ref_start=args.ref_start,
        ref_end=args.ref_end,
        resume=args.resume,
    )
    print_summary_table(rows, has_reference=reference_text is not None)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
