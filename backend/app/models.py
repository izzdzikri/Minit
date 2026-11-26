"""ORM models for meetings, transcript segments, and upload sessions."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import BigInteger, Boolean, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .db import Base


def _utcnow() -> datetime:
    return datetime.now(UTC)


def _new_uuid() -> str:
    return str(uuid.uuid4())


class Meeting(Base):
    __tablename__ = "meetings"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_new_uuid)
    client_meeting_id: Mapped[str] = mapped_column(
        String(128), unique=True, index=True, nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    language_hint: Mapped[str] = mapped_column(String(16), nullable=False, default="ms")
    glossary: Mapped[str | None] = mapped_column(Text, nullable=True)
    silence_ranges_json: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Lifecycle statuses exposed via /status:
    # uploading -> uploaded -> queued -> transcribing -> ready | failed
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="uploaded")
    progress_percent: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    status_message: Mapped[str] = mapped_column(String(255), nullable=False, default="")
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    detected_language: Mapped[str | None] = mapped_column(String(16), nullable=True)
    duration_sec: Mapped[float | None] = mapped_column(Float, nullable=True)
    audio_path: Mapped[str | None] = mapped_column(String(512), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow, onupdate=_utcnow
    )

    segments: Mapped[list[TranscriptSegment]] = relationship(
        back_populates="meeting",
        cascade="all, delete-orphan",
        order_by="TranscriptSegment.start_sec",
    )
    upload_session: Mapped[UploadSession | None] = relationship(
        back_populates="meeting",
        cascade="all, delete-orphan",
        uselist=False,
    )


class TranscriptSegment(Base):
    __tablename__ = "transcript_segments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    meeting_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("meetings.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    speaker_label: Mapped[str] = mapped_column(
        String(64), nullable=False, default="Speaker 1"
    )
    start_sec: Mapped[float] = mapped_column(Float, nullable=False)
    end_sec: Mapped[float] = mapped_column(Float, nullable=False)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    avg_logprob: Mapped[float | None] = mapped_column(Float, nullable=True)
    no_speech_prob: Mapped[float | None] = mapped_column(Float, nullable=True)
    is_loop_flagged: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )

    meeting: Mapped[Meeting] = relationship(back_populates="segments")


class UploadSession(Base):
    __tablename__ = "upload_sessions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_new_uuid)
    meeting_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("meetings.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    file_ext: Mapped[str | None] = mapped_column(String(16), nullable=True)
    total_bytes: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    received_bytes: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    status: Mapped[str] = mapped_column(
        String(32), nullable=False, default="in_progress"
    )

    meeting: Mapped[Meeting] = relationship(back_populates="upload_session")
