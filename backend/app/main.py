"""FastAPI application entrypoint with startup token check, worker lifecycle, and body limits."""

from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse

from .config import Settings, get_settings
from .db import Base, create_session_factory, get_db
from .routers import health, meetings
from .services.rate_limit import upload_rate_limiter
from .services.transcribe import TranscriptionProvider, build_transcription_provider
from .workers.queue import TranscriptionWorkerManager

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)


def create_app(
    settings_override: Settings | None = None,
    provider_override: TranscriptionProvider | None = None,
) -> FastAPI:
    """Construct and configure a FastAPI app instance."""
    settings = settings_override or get_settings()
    settings.ensure_valid_token()

    settings.storage_path.mkdir(parents=True, exist_ok=True)
    upload_rate_limiter.configure(
        max_requests=settings.UPLOAD_RATE_LIMIT_REQUESTS,
        window_seconds=settings.UPLOAD_RATE_LIMIT_WINDOW_SEC,
    )

    engine, session_factory = create_session_factory(settings)
    # Create tables cleanly if starting on an empty DB before Alembic CLI ran.
    Base.metadata.create_all(bind=engine)

    provider = provider_override or build_transcription_provider(settings)
    worker = TranscriptionWorkerManager(
        session_factory=session_factory,
        provider=provider,
        settings=settings,
    )

    @asynccontextmanager
    async def lifespan(app_instance: FastAPI) -> AsyncIterator[None]:
        worker.start()
        try:
            yield
        finally:
            worker.stop()
            engine.dispose()

    # CORS is intentionally NOT enabled for local single-user security.
    app = FastAPI(
        title="Minit Backend",
        version="0.2.0",
        lifespan=lifespan,
    )
    app.state.settings = settings
    app.state.session_factory = session_factory
    app.state.worker = worker

    app.dependency_overrides[get_settings] = lambda: settings

    def _get_scoped_db():
        db = session_factory()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = _get_scoped_db

    @app.middleware("http")
    async def enforce_request_size_limit(request: Request, call_next):
        cl = request.headers.get("content-length")
        if cl is not None:
            try:
                content_len = int(cl)
            except ValueError:
                return JSONResponse(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    content={"detail": "Invalid Content-Length header"},
                )
            if content_len > settings.MAX_REQUEST_BODY_BYTES:
                return JSONResponse(
                    status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                    content={
                        "detail": (
                            f"Request body exceeds limit "
                            f"({settings.MAX_REQUEST_BODY_BYTES} bytes)."
                        )
                    },
                )
        return await call_next(request)

    app.include_router(health.router)
    app.include_router(meetings.router)
    return app


def get_asgi_app() -> FastAPI:
    return create_app()


def __getattr__(name: str) -> FastAPI:
    if name == "app":
        return get_asgi_app()
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
