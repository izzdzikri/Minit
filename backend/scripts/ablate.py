"""Controlled one-variable-at-a-time ablation runner for bitrate, glossary, and conditioning."""

from __future__ import annotations

import argparse
import gc
import json
import re
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path

_BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(_BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(_BACKEND_ROOT))

from app.services.transcribe import format_glossary_prompt  # noqa: E402
from scripts.benchmark import (  # noqa: E402
    UNSCORED_LABEL,
    clean_reference_text,
    compute_wer_cer,
    detect_gpu,
    extract_text_for_range,
    wav_duration_sec,
)

GLOSSARY_ITEMS = (
    "ChatGPT",
    "benchmark",
    "decision tree",
    "synthetic data",
    "missing values",
    "imbalance",
)
DEFAULT_GLOSSARY_TEXT = ", ".join(GLOSSARY_ITEMS)


@dataclass(frozen=True)
class AblationCase:
    name: str
    group: str
    bitrate: str
    condition_on_previous_text: bool
    use_glossary: bool
    wav_relpath: str


CASES: tuple[AblationCase, ...] = (
    AblationCase(
        name="bitrate_32k_cond_false_no_glossary",
        group="bitrate",
        bitrate="32k",
        condition_on_previous_text=False,
        use_glossary=False,
        wav_relpath="bitrate_ab/clip1_32k.wav",
    ),
    AblationCase(
        name="bitrate_48k_cond_false_no_glossary",
        group="bitrate",
        bitrate="48k",
        condition_on_previous_text=False,
        use_glossary=False,
        wav_relpath="bitrate_ab/clip1_48k.wav",
    ),
    AblationCase(
        name="bitrate_64k_cond_false_no_glossary",
        group="bitrate",
        bitrate="64k",
        condition_on_previous_text=False,
        use_glossary=False,
        wav_relpath="bitrate_ab/clip1_64k.wav",
    ),
    AblationCase(
        name="glossary_on_48k_cond_false",
        group="glossary",
        bitrate="48k",
        condition_on_previous_text=False,
        use_glossary=True,
        wav_relpath="bitrate_ab/clip1_48k.wav",
    ),
    AblationCase(
        name="cond_true_48k_no_glossary",
        group="condition_on_previous_text",
        bitrate="48k",
        condition_on_previous_text=True,
        use_glossary=False,
        wav_relpath="bitrate_ab/clip1_48k.wav",
    ),
    AblationCase(
        name="cond_true_32k_no_glossary",
        group="baseline",
        bitrate="32k",
        condition_on_previous_text=True,
        use_glossary=False,
        wav_relpath="bitrate_ab/clip1_32k.wav",
    ),
)


def _normalize_words(text: str) -> str:
    lowered = text.lower()
    cleaned = re.sub(r"[^a-z0-9\s]", " ", lowered)
    return re.sub(r"\s+", " ", cleaned).strip()


def _count_phrase_occurrences(norm_text: str, phrase: str) -> int:
    norm_phrase = _normalize_words(phrase)
    if not norm_phrase:
        return 0
    return len(re.findall(rf"\b{re.escape(norm_phrase)}\b", norm_text))


def find_false_glossary_insertions(
    reference_text: str,
    hypothesis_text: str,
    baseline_hypothesis_text: str | None = None,
    glossary_items: tuple[str, ...] = GLOSSARY_ITEMS,
) -> list[dict]:
    """Return glossary terms/tokens present in hypothesis where reference omits them."""
    norm_ref = _normalize_words(clean_reference_text(reference_text))
    norm_hyp = _normalize_words(hypothesis_text)
    norm_base = (
        _normalize_words(baseline_hypothesis_text)
        if baseline_hypothesis_text is not None
        else None
    )

    tokens_to_check: list[str] = list(glossary_items)
    seen = {t.lower() for t in tokens_to_check}
    for item in glossary_items:
        for tok in _normalize_words(item).split():
            if len(tok) >= 3 and tok not in seen:
                tokens_to_check.append(tok)
                seen.add(tok)

    findings: list[dict] = []
    for term in tokens_to_check:
        hyp_count = _count_phrase_occurrences(norm_hyp, term)
        ref_count = _count_phrase_occurrences(norm_ref, term)
        base_count = (
            _count_phrase_occurrences(norm_base, term) if norm_base is not None else None
        )
        if hyp_count > 0 and ref_count == 0:
            findings.append(
                {
                    "term": term,
                    "ref_count": ref_count,
                    "hyp_count": hyp_count,
                    "baseline_count": base_count,
                    "introduced_by_glossary": (
                        base_count == 0 if base_count is not None else None
                    ),
                }
            )
    return findings


def run_ablation(
    bench_dir: Path,
    out_dir: Path,
    cpu_threads: int,
    resume: bool,
) -> Path:
    from faster_whisper import WhisperModel

    out_dir.mkdir(parents=True, exist_ok=True)
    summary_path = out_dir / "ablation_summary.json"
    existing_map: dict[str, dict] = {}
    if resume and summary_path.is_file():
        prev = json.loads(summary_path.read_text(encoding="utf-8"))
        for row in prev.get("results", []):
            existing_map[row["name"]] = row

    gpu_info = detect_gpu()
    model = WhisperModel(
        "medium",
        device=gpu_info.selected_device,
        compute_type=gpu_info.selected_compute_type,
        cpu_threads=cpu_threads,
    )

    rows: list[dict] = []
    try:
        for case in CASES:
            seg_json_path = out_dir / f"{case.name}_segments.json"
            txt_path = out_dir / f"{case.name}.txt"
            if (
                resume
                and case.name in existing_map
                and seg_json_path.is_file()
                and txt_path.is_file()
            ):
                rows.append(existing_map[case.name])
                continue

            wav_path = bench_dir / case.wav_relpath
            if not wav_path.is_file():
                raise FileNotFoundError(
                    f"Missing prepared WAV for ablation case {case.name}: {wav_path}"
                )
            duration_sec = wav_duration_sec(wav_path)
            prompt = (
                format_glossary_prompt(DEFAULT_GLOSSARY_TEXT)
                if case.use_glossary
                else None
            )

            t0 = time.perf_counter()
            segs_iter, info = model.transcribe(
                str(wav_path),
                language="ms",
                vad_filter=True,
                condition_on_previous_text=case.condition_on_previous_text,
                compression_ratio_threshold=2.4,
                no_speech_threshold=0.6,
                log_prob_threshold=-1.0,
                temperature=[0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                initial_prompt=prompt,
            )
            seg_dicts: list[dict] = []
            for s in segs_iter:
                seg_dicts.append(
                    {
                        "start": round(float(s.start), 2),
                        "end": round(float(s.end), 2),
                        "text": s.text,
                        "avg_logprob": round(float(s.avg_logprob), 4),
                        "no_speech_prob": round(float(s.no_speech_prob), 4),
                        "compression_ratio": round(float(s.compression_ratio), 4),
                    }
                )
            proc_sec = round(time.perf_counter() - t0, 3)
            plain = " ".join(s["text"].strip() for s in seg_dicts if s["text"].strip())
            avg_lp = (
                round(sum(s["avg_logprob"] for s in seg_dicts) / len(seg_dicts), 4)
                if seg_dicts
                else None
            )

            txt_path.write_text(
                "\n".join(
                    f"[{s['start']:07.2f}->{s['end']:07.2f}] ({s['avg_logprob']:.3f}) {s['text'].strip()}"
                    for s in seg_dicts
                )
                + "\n\n--- PLAIN TRANSCRIPT ---\n"
                + plain
                + "\n",
                encoding="utf-8",
            )
            seg_json_path.write_text(
                json.dumps(
                    {
                        **asdict(case),
                        "audio_duration_sec": round(duration_sec, 3),
                        "processing_sec": proc_sec,
                        "detected_language": info.language,
                        "detected_prob": round(float(info.language_probability), 4),
                        "segments": seg_dicts,
                    },
                    indent=2,
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )
            rows.append(
                {
                    **asdict(case),
                    "audio_duration_sec": round(duration_sec, 3),
                    "processing_sec": proc_sec,
                    "rtf": round(proc_sec / duration_sec, 4) if duration_sec else None,
                    "segments_count": len(seg_dicts),
                    "avg_logprob": avg_lp,
                    "wer": None,
                    "cer": None,
                    "scoring_status": UNSCORED_LABEL,
                    "segments_file": str(seg_json_path),
                    "text_file": str(txt_path),
                    "preview_500": plain[:500],
                }
            )
    finally:
        del model
        gc.collect()

    summary_path.write_text(
        json.dumps(
            {
                "scoring_status": UNSCORED_LABEL,
                "reference_range_sec": [None, None],
                "results": rows,
            },
            indent=2,
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )
    return summary_path


def score_ablation(
    summary_path: Path,
    reference_text: str,
    ref_start: float | None,
    ref_end: float | None,
) -> dict:
    payload = json.loads(summary_path.read_text(encoding="utf-8"))
    rows = payload["results"]
    hyps: dict[str, str] = {}

    for row in rows:
        seg_data = json.loads(Path(row["segments_file"]).read_text(encoding="utf-8"))
        hyp = extract_text_for_range(seg_data["segments"], ref_start, ref_end)
        hyps[row["name"]] = hyp
        wer_val, cer_val = compute_wer_cer(reference_text, hyp)
        row["wer"] = round(wer_val, 4)
        row["cer"] = round(cer_val, 4)
        row["scoring_status"] = "SCORED"

    false_insertions = find_false_glossary_insertions(
        reference_text=reference_text,
        hypothesis_text=hyps.get("glossary_on_48k_cond_false", ""),
        baseline_hypothesis_text=hyps.get("bitrate_48k_cond_false_no_glossary", ""),
    )

    payload["scoring_status"] = "SCORED"
    payload["reference_range_sec"] = [ref_start, ref_end]
    payload["false_glossary_insertions"] = false_insertions
    summary_path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    return payload


def main(argv: list[str]) -> int:
    repo_root = Path(__file__).resolve().parents[2]
    bench_dir = repo_root / "backend" / "benchmark_out"
    parser = argparse.ArgumentParser(
        description="Run/score single-variable ablation on Clip 1."
    )
    parser.add_argument("--cpu-threads", type=int, default=6)
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--score-only", action="store_true")
    parser.add_argument("--reference", type=Path, default=None)
    parser.add_argument("--ref-start", type=float, default=None)
    parser.add_argument("--ref-end", type=float, default=None)
    args = parser.parse_args(argv)

    out_dir = bench_dir / "ablation"
    summary_path = out_dir / "ablation_summary.json"

    if not args.score_only:
        summary_path = run_ablation(
            bench_dir=bench_dir,
            out_dir=out_dir,
            cpu_threads=max(1, args.cpu_threads),
            resume=args.resume,
        )

    if args.reference is not None:
        ref_path = args.reference.expanduser().resolve()
        if not ref_path.is_file():
            print(f"Error: reference file not found: {ref_path}", file=sys.stderr)
            return 2
        ref_text = clean_reference_text(ref_path.read_text(encoding="utf-8"))
        if not ref_text:
            print(f"Error: reference file is empty: {ref_path}", file=sys.stderr)
            return 2
        payload = score_ablation(
            summary_path=summary_path,
            reference_text=ref_text,
            ref_start=args.ref_start,
            ref_end=args.ref_end,
        )
        print("=== Controlled Single-Variable Ablation (SCORED) ===")
        for row in payload["results"]:
            print(
                f"{row['name']:<38} | group={row['group']:<27} | "
                f"WER={row['wer']:.2%} | CER={row['cer']:.2%} | "
                f"lp={row['avg_logprob']:.4f} | proc={row['processing_sec']:.2f}s"
            )
        print("\nFalse glossary insertions:")
        print(json.dumps(payload["false_glossary_insertions"], indent=2))
    else:
        payload = json.loads(summary_path.read_text(encoding="utf-8"))
        print(f"=== Controlled Single-Variable Ablation [{UNSCORED_LABEL}] ===")
        for row in payload["results"]:
            print(
                f"{row['name']:<38} | group={row['group']:<27} | "
                f"WER=UNSCORED | lp={row['avg_logprob']:.4f} | proc={row['processing_sec']:.2f}s"
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
