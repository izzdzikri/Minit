"""In-process transcription queue with crash recovery for mid-job restarts."""

from __future__ import annotations

import json
import logging
import queue
import threading
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session, sessionmaker

from ..config import Settings
from ..models import Meeting, TranscriptSegment
from ..services.storage import delete_audio_file
from ..services.transcribe import TranscriptionProvider

logger = logging.getLogger("minit.worker")


class TranscriptionWorkerManager:
    """Serialized background worker queue backed by SQLAlchemy state."""

    def __init__(
        self,
        *,
        session_factory: sessionmaker[Session],
        provider: TranscriptionProvider,
        settings: Settings,
    ) -> None:
        self._session_factory = session_factory
        self._provider = provider
        self._settings = settings
        self._queue: queue.Queue[str | None] = queue.Queue()
        self._state_lock = threading.Lock()
        self._pending_or_active: set[str] = set()
        self._threads: list[threading.Thread] = []
        self._stop_event = threading.Event()

    def start(self) -> None:
        self._stop_event.clear()
        self.recover_interrupted_jobs()
        worker_count = max(1, self._settings.MAX_CONCURRENT_JOBS)
        for idx in range(worker_count):
            t = threading.Thread(
                target=self._run_loop,
                name=f"transcribe-worker-{idx}",
                daemon=True,
            )
            t.start()
            self._threads.append(t)

    def stop(self, timeout_sec: float = 5.0) -> None:
        self._stop_event.set()
        for _ in self._threads:
            self._queue.put(None)
        for t in self._threads:
            t.join(timeout=timeout_sec)
        self._threads.clear()

    def recover_interrupted_jobs(self) -> int:
        """Re-queue any meetings interrupted in `transcribing` or `queued` state on startup."""
        recovered_ids: list[str] = []
        with self._session_factory() as db:
            rows = db.scalars(
                select(Meeting).where(Meeting.status.in_(["transcribing", "queued"]))
            ).all()
            for row in rows:
                if row.status == "transcribing":
                    row.status = "queued"
                    row.progress_percent = 5
                    row.status_message = "Server restarted; transcription re-queued."
                    row.error_message = None
                recovered_ids.append(row.id)
            if rows:
                db.commit()

        for mid in recovered_ids:
            self.enqueue(mid)
        if recovered_ids:
            logger.info("Recovered %d pending transcription job(s).", len(recovered_ids))
        return len(recovered_ids)

    def enqueue(self, meeting_id: str) -> bool:
        with self._state_lock:
            if meeting_id in self._pending_or_active:
                return False
            self._pending_or_active.add(meeting_id)
            self._queue.put(meeting_id)
            return True

    def wait_until_idle(self, timeout_sec: float = 10.0) -> bool:
        """Helper used by tests to drain pending queued items cleanly."""
        import time

        deadline = time.monotonic() + timeout_sec
        while time.monotonic() < deadline:
            with self._state_lock:
                empty = not self._pending_or_active and self._queue.empty()
            if empty:
                return True
            time.sleep(0.05)
        return False

    def _run_loop(self) -> None:
        while not self._stop_event.is_set():
            try:
                meeting_id = self._queue.get(timeout=0.5)
            except queue.Empty:
                continue
            if meeting_id is None:
                self._queue.task_done()
                break
            try:
                self._process_meeting(meeting_id)
            finally:
                with self._state_lock:
                    self._pending_or_active.discard(meeting_id)
                self._queue.task_done()

    def _update_progress(self, meeting_id: str, percent: int, message: str) -> None:
        with self._session_factory() as db:
            meeting = db.get(Meeting, meeting_id)
            if meeting is None or meeting.status == "failed":
                return
            meeting.progress_percent = max(0, min(100, percent))
            meeting.status_message = message[:255]
            db.commit()

    def _process_meeting(self, meeting_id: str) -> None:
        audio_path_str: str | None = None
        language_hint = self._settings.WHISPER_LANGUAGE_DEFAULT
        glossary: str | None = None
        silence_ranges: list[tuple[float, float]] | None = None

        with self._session_factory() as db:
            meeting = db.get(Meeting, meeting_id)
            if meeting is None:
                return
            if not meeting.audio_path or not Path(meeting.audio_path).is_file():
                meeting.status = "failed"
                meeting.progress_percent = 0
                meeting.status_message = "Audio file missing on server."
                meeting.error_message = "Uploaded audio file could not be found."
                db.commit()
                return

            audio_path_str = meeting.audio_path
            language_hint = meeting.language_hint
            glossary = meeting.glossary
            if meeting.silence_ranges_json:
                try:
                    raw = json.loads(meeting.silence_ranges_json)
                    if isinstance(raw, list):
                        silence_ranges = [
                            (float(r["start_sec"]), float(r["end_sec"]))
                            for r in raw
                            if isinstance(r, dict)
                            and "start_sec" in r
                            and "end_sec" in r
                        ]
                except Exception:
                    silence_ranges = None

            meeting.status = "transcribing"
            meeting.progress_percent = 10
            meeting.status_message = "Starting transcription..."
            meeting.error_message = None
            db.commit()

        logger.info("Transcribing meeting_id=%s language_hint=%s", meeting_id, language_hint)

        try:
            result = self._provider.transcribe_audio(
                Path(audio_path_str),
                language_hint=language_hint,
                glossary=glossary,
                silence_ranges=silence_ranges,
                progress_cb=lambda pct, msg: self._update_progress(
                    meeting_id, pct, msg
                ),
            )
        except Exception as exc:
            err_msg = f"Transcription error: {type(exc).__name__}"
            logger.exception("Transcription failed for meeting_id=%s", meeting_id)
            with self._session_factory() as db:
                meeting = db.get(Meeting, meeting_id)
                if meeting is not None:
                    meeting.status = "failed"
                    meeting.progress_percent = 0
                    meeting.status_message = "Transcription failed."
                    meeting.error_message = f"{err_msg}: {str(exc)[:180]}"
                    db.commit()
            return

        with self._session_factory() as db:
            meeting = db.get(Meeting, meeting_id)
            if meeting is None:
                # Meeting was deleted while transcribing; ensure audio cleanup.
                delete_audio_file(self._settings.storage_path, audio_path_str)
                return

            existing = db.scalars(
                select(TranscriptSegment).where(
                    TranscriptSegment.meeting_id == meeting_id
                )
            ).all()
            for row in existing:
                db.delete(row)
            db.flush()

            for seg in result.segments:
                db.add(
                    TranscriptSegment(
                        meeting_id=meeting_id,
                        speaker_label=seg.speaker_label,
                        start_sec=seg.start_sec,
                        end_sec=seg.end_sec,
                        text=seg.text,
                        avg_logprob=seg.avg_logprob,
                        no_speech_prob=seg.no_speech_prob,
                        is_loop_flagged=seg.is_loop_flagged,
                    )
                )

            meeting.status = "ready"
            meeting.progress_percent = 100
            meeting.status_message = "Transcription complete."
            meeting.error_message = None
            meeting.detected_language = result.detected_language
            if result.duration_sec > 0:
                meeting.duration_sec = result.duration_sec
            if self._settings.DELETE_AUDIO_AFTER_TRANSCRIBE:
                delete_audio_file(self._settings.storage_path, audio_path_str)
                meeting.audio_path = None
            db.commit()

        logger.info(
            "Transcription completed meeting_id=%s segments=%d duration=%.1fs",
            meeting_id,
            len(result.segments),
            result.duration_sec,
        )
