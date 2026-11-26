"""Tests for transcription chunking, glossary formatting, loop detection, and real model clip."""

from __future__ import annotations

import struct
import wave
from pathlib import Path

import pytest

from app.config import BACKEND_ROOT, Settings
from app.services.transcribe import (
    FasterWhisperProvider,
    detect_repetition_loop,
    format_glossary_prompt,
    plan_audio_chunks,
)


def _write_test_wav(path: Path, segments_rms: list[tuple[float, int]]) -> float:
    """Create a 16 kHz mono WAV from `(duration_sec, amplitude_int16)` blocks."""
    sr = 16000
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        for dur, amp in segments_rms:
            n = int(round(dur * sr))
            if amp == 0:
                wf.writeframes(b"\x00\x00" * n)
            else:
                # Alternating sign at 500 Hz square wave
                frame = struct.pack("<h", amp) * 16 + struct.pack("<h", -amp) * 16
                wf.writeframes((frame * (n // 32 + 1))[: n * 2])
    return sum(d for d, _ in segments_rms)


def test_detect_repetition_loop_threshold_gt_four() -> None:
    # Exactly 4 repeats must NOT trigger (> 4 required)
    assert detect_repetition_loop("ialah ialah ialah ialah", max_consecutive_repeats=4) is None
    # 5 repeats MUST trigger
    assert detect_repetition_loop("ialah ialah ialah ialah ialah", max_consecutive_repeats=4) == "ialah"
    # Multi-word phrase repeated 5 times
    assert (
        detect_repetition_loop(
            "the value of the value of the value of the value of the value of",
            max_consecutive_repeats=4,
        )
        == "the value of"
    )
    assert detect_repetition_loop("Normal mixed Malay English discussion.") is None


def test_format_glossary_prompt_respects_budget() -> None:
    assert format_glossary_prompt(None) is None
    assert format_glossary_prompt("   ") is None
    short = format_glossary_prompt("ChatGPT, benchmark; decision tree\nsynthetic data")
    assert short == "Technical terms: ChatGPT, benchmark, decision tree, synthetic data."

    long_terms = ", ".join(f"TermNumber{i}" for i in range(60))
    capped = format_glossary_prompt(long_terms, max_chars=120)
    assert capped is not None
    assert len(capped) <= 122
    assert capped.startswith("Technical terms: ")


def test_plan_audio_chunks_cuts_on_silence_or_uses_overlap(tmp_path: Path) -> None:
    wav_silence = tmp_path / "silence_boundary.wav"
    # 28s tone, 2s silence right around 30s target, 20s tone => total 50s
    total_dur = _write_test_wav(wav_silence, [(29.0, 5000), (2.0, 0), (19.0, 5000)])
    chunks = plan_audio_chunks(
        wav_silence,
        total_duration_sec=total_dur,
        chunk_duration_sec=30.0,
        overlap_sec=2.0,
        silence_search_window_sec=5.0,
    )
    assert len(chunks) == 2
    assert chunks[0].cut_on_silence is True
    assert 29.0 <= chunks[0].end_sec <= 31.0
    assert chunks[1].start_sec == chunks[0].end_sec

    wav_continuous = tmp_path / "continuous.wav"
    total_cont = _write_test_wav(wav_continuous, [(55.0, 8000)])
    chunks_cont = plan_audio_chunks(
        wav_continuous,
        total_duration_sec=total_cont,
        chunk_duration_sec=30.0,
        overlap_sec=2.0,
        silence_search_window_sec=5.0,
    )
    assert len(chunks_cont) == 2
    assert chunks_cont[0].cut_on_silence is False
    # Second chunk starts 2s before chunk 0 ends
    assert chunks_cont[0].end_sec > chunks_cont[1].start_sec


def test_real_faster_whisper_provider_on_clip1_slice_when_available(
    tmp_path: Path,
) -> None:
    """Smoke-test real FasterWhisperProvider if benchmark clip + cached small/base model exist."""
    clip = (
        BACKEND_ROOT
        / "benchmark_out"
        / "bitrate_ab"
        / "clip1_48k.m4a"
    )
    if not clip.is_file():
        pytest.skip("Local clip1_48k.m4a fixture not present; skipped real-model test.")

    # Trim an 18s sample from clip1 via ffmpeg inside tmp_path so test runs in ~3s.
    import shutil
    import subprocess

    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        pytest.skip("ffmpeg unavailable")

    short_m4a = tmp_path / "clip1_18s.m4a"
    subprocess.run(
        [
            ffmpeg,
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            str(clip),
            "-t",
            "18",
            "-c:a",
            "copy",
            str(short_m4a),
        ],
        check=True,
    )

    # Use small locally-cached model in pytest so suite finishes in seconds while proving
    # real faster-whisper integration (production default remains `medium` in config.py).
    cfg = Settings(
        API_TOKEN="real-provider-test-token",
        DATABASE_URL=f"sqlite:///{tmp_path / 'real.db'}",
        STORAGE_DIR=str(tmp_path / "storage"),
        WHISPER_MODEL_SIZE="small",
        WHISPER_COMPUTE_TYPE="int8",
        WHISPER_LANGUAGE_DEFAULT="ms",
    )
    provider = FasterWhisperProvider(cfg)
    result = provider.transcribe_audio(
        short_m4a,
        language_hint="ms",
        glossary="ChatGPT, benchmark, synthetic data, missing values, imbalance",
    )
    assert result.duration_sec > 15.0
    assert len(result.segments) >= 1
    combined = " ".join(s.text for s in result.segments).lower()
    assert any(tok in combined for tok in ("noise", "imbalance", "synthetic", "synthetik"))
    assert all(s.speaker_label == "Speaker 1" for s in result.segments)
    assert all(s.avg_logprob is not None for s in result.segments)


def test_clean_reference_text_strips_comments_and_timestamps() -> None:
    from scripts.benchmark import clean_reference_text, compute_wer_cer

    draft_like_ref = (
        "# DRAFT from small. Edit every line by listening.\n"
        "# Another comment line\n"
        "[00:00] Sebab synthetic tak ada noise.\n"
        "[01:05] Masalah tu satu [01:12] missing values!\n"
    )
    cleaned = clean_reference_text(draft_like_ref)
    assert cleaned == "Sebab synthetic tak ada noise. Masalah tu satu missing values!"
    wer, cer = compute_wer_cer(
        draft_like_ref,
        "sebab synthetic tak ada noise masalah tu satu missing values",
    )
    assert wer == 0.0
    assert cer == 0.0
