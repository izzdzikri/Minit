"""Health check endpoint under /api."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from ..config import Settings, get_settings
from ..schemas import HealthResponse
from ..services.auth import require_bearer_token

router = APIRouter(prefix="/api", tags=["health"])


@router.get("/health", response_model=HealthResponse)
def get_health(
    _token: Annotated[str, Depends(require_bearer_token)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> HealthResponse:
    return HealthResponse(
        status="ok",
        provider=settings.TRANSCRIPTION_PROVIDER,
        model=settings.WHISPER_MODEL_SIZE,
        compute_type=settings.WHISPER_COMPUTE_TYPE,
        default_language=settings.WHISPER_LANGUAGE_DEFAULT,
    )
