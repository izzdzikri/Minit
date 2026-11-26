"""Application configuration loaded strictly from `.env` / environment."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_ROOT = Path(__file__).resolve().parents[1]

# Placeholder values that must never be accepted in a running server.
PLACEHOLDER_TOKENS = frozenset(
    {
        "",
        "change-me",
        "change-me-replace-with-random-token",
        "changeme",
        "your-secret-token-here",
        "secret",
        "dev-token",
        "token",
    }
)


class Settings(BaseSettings):
    """Typed backend configuration sourced from `.env` and env vars."""

    model_config = SettingsConfigDict(
        env_file=str(BACKEND_ROOT / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=True,
    )

    # Single shared API token for Phase 2; real user accounts come in Phase 4.
    API_TOKEN: str = Field(default="")

    DATABASE_URL: str = Field(default="sqlite:///./storage/minit.db")
    STORAGE_DIR: str = Field(default="./storage")

    MAX_UPLOAD_BYTES: int = Field(default=524_288_000, ge=1024)
    MAX_REQUEST_BODY_BYTES: int = Field(default=10_485_760, ge=1024)
    ALLOWED_AUDIO_EXTENSIONS: str = Field(default="m4a,aac,mp3,wav,webm")
    UPLOAD_RATE_LIMIT_REQUESTS: int = Field(default=600, ge=1)
    UPLOAD_RATE_LIMIT_WINDOW_SEC: int = Field(default=60, ge=1)

    TRANSCRIPTION_PROVIDER: str = Field(default="faster_whisper")
    WHISPER_MODEL_SIZE: str = Field(default="medium")
    WHISPER_COMPUTE_TYPE: str = Field(default="int8")
    WHISPER_LANGUAGE_DEFAULT: str = Field(default="ms")
    WHISPER_CPU_THREADS: int = Field(default=6, ge=1)
    WHISPER_VAD_FILTER: bool = Field(default=True)
    WHISPER_CONDITION_ON_PREVIOUS_TEXT: bool = Field(default=False)
    WHISPER_COMPRESSION_RATIO_THRESHOLD: float = Field(default=2.4, gt=1.0)
    WHISPER_NO_SPEECH_THRESHOLD: float = Field(default=0.6, ge=0.0, le=1.0)
    WHISPER_LOG_PROB_THRESHOLD: float = Field(default=-1.0)
    WHISPER_TEMPERATURES: str = Field(default="0.0,0.2,0.4,0.6,0.8,1.0")
    WHISPER_CHUNK_DURATION_SEC: int = Field(default=900, ge=30)
    WHISPER_CHUNK_OVERLAP_SEC: float = Field(default=2.0, ge=0.0, le=15.0)
    LOOP_REPEAT_THRESHOLD: int = Field(default=4, ge=2)

    MAX_CONCURRENT_JOBS: int = Field(default=1, ge=1)
    DELETE_AUDIO_AFTER_TRANSCRIBE: bool = Field(default=False)

    @field_validator("TRANSCRIPTION_PROVIDER")
    @classmethod
    def _validate_provider(cls, value: str) -> str:
        norm = value.strip().lower()
        if norm not in {"faster_whisper", "cloud"}:
            raise ValueError("TRANSCRIPTION_PROVIDER must be 'faster_whisper' or 'cloud'")
        return norm

    @field_validator("WHISPER_LANGUAGE_DEFAULT")
    @classmethod
    def _validate_language_default(cls, value: str) -> str:
        norm = value.strip().lower()
        if norm not in {"ms", "en", "auto"}:
            raise ValueError("WHISPER_LANGUAGE_DEFAULT must be 'ms', 'en', or 'auto'")
        return norm

    @property
    def allowed_extensions_set(self) -> frozenset[str]:
        return frozenset(
            ext.strip().lower().lstrip(".")
            for ext in self.ALLOWED_AUDIO_EXTENSIONS.split(",")
            if ext.strip()
        )

    @property
    def temperatures_list(self) -> list[float]:
        values = [float(x.strip()) for x in self.WHISPER_TEMPERATURES.split(",") if x.strip()]
        return values or [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]

    @property
    def storage_path(self) -> Path:
        raw = Path(self.STORAGE_DIR)
        return raw if raw.is_absolute() else (BACKEND_ROOT / raw).resolve()

    def resolved_database_url(self) -> str:
        if self.DATABASE_URL.startswith("sqlite:///./"):
            rel = self.DATABASE_URL.removeprefix("sqlite:///./")
            abs_db = (BACKEND_ROOT / rel).resolve()
            abs_db.parent.mkdir(parents=True, exist_ok=True)
            return f"sqlite:///{abs_db}"
        return self.DATABASE_URL

    def ensure_valid_token(self) -> None:
        token = self.API_TOKEN.strip()
        if not token or token.lower() in PLACEHOLDER_TOKENS:
            raise RuntimeError(
                "Refusing to start: set a non-placeholder API_TOKEN in backend/.env"
            )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
