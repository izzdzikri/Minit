"""Shared pytest fixtures for FastAPI API and worker tests."""

from __future__ import annotations

import time
from collections.abc import Callable
from pathlib import Path

import pytest

from app.config import Settings
from app.services.rate_limit import upload_rate_limiter
from app.services.transcribe import (
    TranscriptionProvider,
    TranscriptionResult,
    TranscriptSegmentData,
)


class FakeTranscriptionProvider(TranscriptionProvider):
    """Deterministic fake provider for fast API & worker lifecycle tests."""

    def __init__(
        self,
        *,
        should_fail: bool = False,
        delay_sec: float = 0.0,
        segments: list[TranscriptSegmentData] | None = None,
    ) -> None:
        self.should_fail = should_fail
        self.delay_sec = delay_sec
        self.calls: list[dict] = []
        self.segments = segments or [
            TranscriptSegmentData(
                start_sec=0.0,
                end_sec=2.4,
                text="Okay guys, kita mula benchmark meeting hari ini.",
                speaker_label="Speaker 1",
                avg_logprob=-0.28,
                no_speech_prob=0.04,
                is_loop_flagged=False,
            ),
            TranscriptSegmentData(
                start_sec=2.5,
                end_sec=5.1,
                text="Pastikan audio upload boleh resume lepas putus.",
                speaker_label="Speaker 1",
                avg_logprob=-0.65,
                no_speech_prob=0.12,
                is_loop_flagged=False,
            ),
        ]

    def transcribe_audio(
        self,
        audio_path: Path,
        *,
        language_hint: str,
        glossary: str | None = None,
        silence_ranges: list[tuple[float, float]] | None = None,
        progress_cb: Callable[[int, str], None] | None = None,
    ) -> TranscriptionResult:
        self.calls.append(
            {
                "audio_path": str(audio_path),
                "language_hint": language_hint,
                "glossary": glossary,
                "silence_ranges": silence_ranges,
            }
        )
        if progress_cb:
            progress_cb(30, "Fake preparing audio...")
        if self.delay_sec > 0:
            time.sleep(self.delay_sec)
        if self.should_fail:
            raise RuntimeError("Simulated provider crash")
        if progress_cb:
            progress_cb(85, "Fake finalizing transcript...")
        return TranscriptionResult(
            duration_sec=5.2,
            detected_language="ms" if language_hint == "auto" else language_hint,
            segments=list(self.segments),
        )


@pytest.fixture(autouse=True)
def reset_rate_limiter() -> None:
    upload_rate_limiter.reset()


@pytest.fixture()
def test_settings(tmp_path: Path) -> Settings:
    db_file = tmp_path / "test_minit.db"
    storage_dir = tmp_path / "storage"
    return Settings(
        API_TOKEN="test-secret-token-phase-2-xyz",
        DATABASE_URL=f"sqlite:///{db_file}",
        STORAGE_DIR=str(storage_dir),
        MAX_UPLOAD_BYTES=1_000_000,
        MAX_REQUEST_BODY_BYTES=256_000,
        UPLOAD_RATE_LIMIT_REQUESTS=100,
        UPLOAD_RATE_LIMIT_WINDOW_SEC=60,
        DELETE_AUDIO_AFTER_TRANSCRIBE=False,
    )


@pytest.fixture()
def auth_headers(test_settings: Settings) -> dict[str, str]:
    return {"Authorization": f"Bearer {test_settings.API_TOKEN}"}
