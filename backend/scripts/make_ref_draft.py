"""Generate a timestamped draft transcript and 0-100s audio slice to speed up manual reference typing."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

_BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(_BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(_BACKEND_ROOT))

from app.services.transcribe import extract_wav_slice  # noqa: E402
from scripts.benchmark import ClipSpec, detect_gpu, prepare_wav_versions  # noqa: E402

HEADER_COMMENT = (
    "# DRAFT from small. Edit every line by listening. "
    "Delete timestamps and this header when done, then save as ref_clip1.txt."
)


def _format_mmss(seconds: float) -> str:
    whole = max(0, int(seconds))
    mins, secs = divmod(whole, 60)
    return f"{mins:02d}:{secs:02d}"


def build_reference_draft(cpu_threads: int = 6) -> tuple[Path, Path]:
    from faster_whisper import WhisperModel

    repo_root = _BACKEND_ROOT.parent
    bench_dir = _BACKEND_ROOT / "benchmark_out"
    clips_dir = bench_dir / "prepared_clips"
    clip1_orig_wav = clips_dir / "clip1_5min_original.wav"

    if not clip1_orig_wav.is_file():
        src_m4a = (
            bench_dir
            / "audio"
            / "Diskusi Pemrosesan Data Sintetis dan Persiapan Laporan Proyek.m4a"
        )
        if not src_m4a.is_file():
            raise FileNotFoundError(
                f"Neither prepared WAV ({clip1_orig_wav}) nor source M4A ({src_m4a}) was found."
            )
        prepared = prepare_wav_versions(
            ClipSpec(
                name="clip1_5min",
                source_path=src_m4a,
                start_sec=120.0,
                duration_sec=300.0,
            ),
            clips_dir=clips_dir,
            versions=("original",),
        )
        clip1_orig_wav = prepared["original"][0]

    slice_wav = bench_dir / "ref_clip1_0-100s.wav"
    draft_txt = bench_dir / "ref_clip1_DRAFT.txt"
    extract_wav_slice(clip1_orig_wav, slice_wav, 0.0, 100.0)

    gpu_info = detect_gpu()
    model = WhisperModel(
        "small",
        device=gpu_info.selected_device,
        compute_type=gpu_info.selected_compute_type,
        cpu_threads=max(1, cpu_threads),
    )
    segs_iter, _ = model.transcribe(
        str(slice_wav),
        language="ms",
        vad_filter=True,
        initial_prompt=None,
    )

    lines = [HEADER_COMMENT]
    for seg in segs_iter:
        txt = seg.text.strip()
        if not txt:
            continue
        lines.append(f"[{_format_mmss(float(seg.start))}] {txt}")

    draft_txt.write_text("\n".join(lines) + "\n", encoding="utf-8")
    del model

    print(f"Wrote 100s audio slice : {slice_wav.relative_to(repo_root)}")
    print(f"Wrote draft transcript : {draft_txt.relative_to(repo_root)}")
    print("\nOnce you've edited and saved ref_clip1.txt, run:")
    print(
        "backend/.venv/bin/python backend/scripts/benchmark.py "
        "--score-summary backend/benchmark_out/benchmark_summary.json "
        "--reference backend/benchmark_out/ref_clip1.txt "
        "--ref-clip clip1_5min --ref-start 0 --ref-end 100"
    )
    return slice_wav, draft_txt


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Create ref_clip1_DRAFT.txt and ref_clip1_0-100s.wav from Clip 1."
    )
    parser.add_argument(
        "--cpu-threads",
        type=int,
        default=min(6, os.cpu_count() or 4),
    )
    args = parser.parse_args(argv)
    build_reference_draft(cpu_threads=args.cpu_threads)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
