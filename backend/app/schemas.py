"""Pydantic request and response schemas for the API."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

LanguageHint = Literal["ms", "en", "auto"]


class SilenceRangeIn(BaseModel):
    start_sec: float = Field(ge=0.0)
    end_sec: float = Field(gt=0.0)


class MeetingCreateRequest(BaseModel):
    client_meeting_id: str = Field(min_length=1, max_length=128)
    title: str = Field(min_length=1, max_length=255)
    language_hint: str = Field(default="ms")
    glossary: str | None = Field(default=None, max_length=1000)
    duration_sec: float | None = Field(default=None, ge=0.0)
    total_bytes: int | None = Field(default=None, ge=1)
    file_ext: str | None = Field(default=None, max_length=16)

    @field_validator("client_meeting_id", "title")
    @classmethod
    def _strip_required(cls, v: str) -> str:
        s = v.strip()
        if not s:
            raise ValueError("Field cannot be blank")
        return s

    @field_validator("language_hint")
    @classmethod
    def _normalize_language(cls, v: str) -> str:
        norm = v.strip().lower()
        if norm == "mixed":
            # Map Phase 1 legacy label cleanly to Malay default for code-switching.
            return "ms"
        if norm not in {"ms", "en", "auto"}:
            raise ValueError("language_hint must be 'ms', 'en', or 'auto'")
        return norm


class ProcessRequest(BaseModel):
    language_hint: str | None = Field(default=None)
    glossary: str | None = Field(default=None, max_length=1000)
    silence_ranges: list[SilenceRangeIn] | None = Field(default=None)

    @field_validator("language_hint")
    @classmethod
    def _normalize_opt_lang(cls, v: str | None) -> str | None:
        if v is None:
            return None
        norm = v.strip().lower()
        if norm == "mixed":
            return "ms"
        if norm not in {"ms", "en", "auto"}:
            raise ValueError("language_hint must be 'ms', 'en', or 'auto'")
        return norm


class TranscriptSegmentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    speaker_label: str
    start_sec: float
    end_sec: float
    text: str
    avg_logprob: float | None = None
    no_speech_prob: float | None = None
    is_loop_flagged: bool = False


class UploadSessionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    meeting_id: str
    total_bytes: int
    received_bytes: int
    status: str


class UploadChunkResponse(BaseModel):
    meeting_id: str
    upload_session_id: str
    received_bytes: int
    total_bytes: int
    complete: bool
    status: str


class MeetingStatusResponse(BaseModel):
    meeting_id: str
    status: str
    progress_percent: int
    message: str
    error_message: str | None = None


class MeetingResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    client_meeting_id: str
    title: str
    language_hint: str
    glossary: str | None = None
    status: str
    progress_percent: int
    status_message: str
    error_message: str | None = None
    detected_language: str | None = None
    duration_sec: float | None = None
    created_at: datetime
    updated_at: datetime
    upload_session: UploadSessionOut | None = None
    segments: list[TranscriptSegmentOut] = Field(default_factory=list)


class HealthResponse(BaseModel):
    status: str
    provider: str
    model: str
    compute_type: str
    default_language: str
