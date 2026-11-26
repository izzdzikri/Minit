"""Meetings, resumable chunked uploads, processing, and transcript endpoints."""

from __future__ import annotations

import json
import logging
from typing import Annotated

from fastapi import (
    APIRouter,
    Body,
    Depends,
    Header,
    HTTPException,
    Query,
    Request,
    Response,
    status,
)
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload

from ..config import Settings, get_settings
from ..db import get_db
from ..models import Meeting, UploadSession
from ..schemas import (
    MeetingCreateRequest,
    MeetingResponse,
    MeetingStatusResponse,
    ProcessRequest,
    UploadChunkResponse,
)
from ..services.auth import require_bearer_token
from ..services.rate_limit import upload_rate_limiter
from ..services.storage import (
    delete_audio_file,
    get_meeting_upload_lock,
    parse_content_range,
    safe_audio_path,
    sanitize_extension,
    write_chunk_at_expected_offset,
)
from ..workers.queue import TranscriptionWorkerManager

logger = logging.getLogger("minit.api.meetings")

router = APIRouter(prefix="/api/meetings", tags=["meetings"])

_MIME_TO_EXT = {
    "audio/mp4": "m4a",
    "audio/m4a": "m4a",
    "audio/x-m4a": "m4a",
    "audio/aac": "aac",
    "audio/aacp": "aac",
    "audio/mpeg": "mp3",
    "audio/mp3": "mp3",
    "audio/wav": "wav",
    "audio/x-wav": "wav",
    "audio/wave": "wav",
    "audio/webm": "webm",
    "video/webm": "webm",
}


def get_worker(request: Request) -> TranscriptionWorkerManager:
    return request.app.state.worker


def _resolve_upload_extension(
    *,
    x_file_extension: str | None,
    x_filename: str | None,
    content_type: str | None,
    existing_ext: str | None,
    allowed: frozenset[str],
) -> str:
    raw_ext = x_file_extension
    if not raw_ext and x_filename:
        raw_ext = x_filename
    if not raw_ext and content_type:
        base_ct = content_type.split(";", 1)[0].strip().lower()
        raw_ext = _MIME_TO_EXT.get(base_ct)
    if not raw_ext:
        raw_ext = existing_ext
    ext = sanitize_extension(raw_ext, allowed)
    if existing_ext and ext != existing_ext:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Audio type changed mid-upload ({existing_ext} vs {ext}).",
        )
    return ext


def _load_meeting_full(db: Session, meeting_id: str) -> Meeting | None:
    stmt = (
        select(Meeting)
        .options(selectinload(Meeting.segments), selectinload(Meeting.upload_session))
        .where(Meeting.id == meeting_id)
    )
    return db.scalars(stmt).first()


async def _read_bounded_body(request: Request, max_bytes: int) -> bytes:
    buf = bytearray()
    async for chunk in request.stream():
        if not chunk:
            continue
        buf.extend(chunk)
        if len(buf) > max_bytes:
            raise HTTPException(
                status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                detail=f"Request body exceeds chunk limit ({max_bytes} bytes).",
            )
    return bytes(buf)


@router.post("", response_model=MeetingResponse, status_code=status.HTTP_201_CREATED)
def create_meeting(
    payload: MeetingCreateRequest,
    response: Response,
    _token: Annotated[str, Depends(require_bearer_token)],
    db: Annotated[Session, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> Meeting:
    if payload.total_bytes is not None and payload.total_bytes > settings.MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail=f"File size exceeds server limit ({settings.MAX_UPLOAD_BYTES} bytes).",
        )
    validated_ext: str | None = None
    if payload.file_ext:
        validated_ext = sanitize_extension(
            payload.file_ext, settings.allowed_extensions_set
        )

    existing = db.scalars(
        select(Meeting)
        .options(selectinload(Meeting.segments), selectinload(Meeting.upload_session))
        .where(Meeting.client_meeting_id == payload.client_meeting_id)
    ).first()
    if existing is not None:
        response.status_code = status.HTTP_200_OK
        return existing

    meeting = Meeting(
        client_meeting_id=payload.client_meeting_id,
        title=payload.title,
        language_hint=payload.language_hint,
        glossary=payload.glossary,
        duration_sec=payload.duration_sec,
        status="uploading",
        progress_percent=0,
        status_message="Waiting for audio upload.",
    )
    upload_session = UploadSession(
        meeting=meeting,
        file_ext=validated_ext,
        total_bytes=payload.total_bytes or 0,
        received_bytes=0,
        status="in_progress",
    )
    db.add(meeting)
    db.add(upload_session)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raced = db.scalars(
            select(Meeting)
            .options(
                selectinload(Meeting.segments), selectinload(Meeting.upload_session)
            )
            .where(Meeting.client_meeting_id == payload.client_meeting_id)
        ).first()
        if raced is not None:
            response.status_code = status.HTTP_200_OK
            return raced
        raise

    loaded = _load_meeting_full(db, meeting.id)
    assert loaded is not None
    logger.info("Created meeting_id=%s", loaded.id)
    return loaded


@router.get("/{meeting_id}/upload")
def get_upload_offset(
    meeting_id: str,
    _token: Annotated[str, Depends(require_bearer_token)],
    db: Annotated[Session, Depends(get_db)],
) -> JSONResponse:
    meeting = _load_meeting_full(db, meeting_id)
    if meeting is None or meeting.upload_session is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meeting not found")
    sess = meeting.upload_session
    headers = {
        "Upload-Offset": str(sess.received_bytes),
        "Upload-Length": str(sess.total_bytes),
        "X-Upload-Status": sess.status,
    }
    return JSONResponse(
        status_code=status.HTTP_200_OK,
        content={
            "meeting_id": meeting.id,
            "upload_session_id": sess.id,
            "received_bytes": sess.received_bytes,
            "total_bytes": sess.total_bytes,
            "status": sess.status,
        },
        headers=headers,
    )


@router.head("/{meeting_id}/upload")
def head_upload_offset(
    meeting_id: str,
    _token: Annotated[str, Depends(require_bearer_token)],
    db: Annotated[Session, Depends(get_db)],
) -> Response:
    meeting = _load_meeting_full(db, meeting_id)
    if meeting is None or meeting.upload_session is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meeting not found")
    sess = meeting.upload_session
    return Response(
        status_code=status.HTTP_200_OK,
        headers={
            "Upload-Offset": str(sess.received_bytes),
            "Upload-Length": str(sess.total_bytes),
            "X-Upload-Status": sess.status,
        },
    )


@router.put("/{meeting_id}/upload", response_model=UploadChunkResponse)
async def upload_chunk(
    meeting_id: str,
    request: Request,
    token: Annotated[str, Depends(require_bearer_token)],
    db: Annotated[Session, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_settings)],
    worker: Annotated[TranscriptionWorkerManager, Depends(get_worker)],
    content_range: Annotated[str | None, Header(alias="Content-Range")] = None,
    x_file_extension: Annotated[str | None, Header(alias="X-File-Extension")] = None,
    x_filename: Annotated[str | None, Header(alias="X-Filename")] = None,
    content_type: Annotated[str | None, Header(alias="Content-Type")] = None,
    auto_process: Annotated[bool, Query()] = True,
) -> UploadChunkResponse:
    upload_rate_limiter.check_and_consume(token)

    start, end, total = parse_content_range(
        content_range,
        max_upload_bytes=settings.MAX_UPLOAD_BYTES,
        max_chunk_bytes=settings.MAX_REQUEST_BODY_BYTES,
    )
    chunk_bytes = await _read_bounded_body(request, settings.MAX_REQUEST_BODY_BYTES)
    expected_chunk_len = end - start + 1
    if len(chunk_bytes) != expected_chunk_len:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Body length ({len(chunk_bytes)}) does not match Content-Range "
                f"length ({expected_chunk_len})."
            ),
        )

    lock = get_meeting_upload_lock(meeting_id)
    should_enqueue = False
    with lock:
        meeting = _load_meeting_full(db, meeting_id)
        if meeting is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Meeting not found",
            )
        sess = meeting.upload_session
        if sess is None:
            sess = UploadSession(
                meeting_id=meeting.id,
                total_bytes=total,
                received_bytes=0,
                status="in_progress",
            )
            db.add(sess)
            db.flush()

        ext = _resolve_upload_extension(
            x_file_extension=x_file_extension,
            x_filename=x_filename,
            content_type=content_type,
            existing_ext=sess.file_ext,
            allowed=settings.allowed_extensions_set,
        )

        if sess.total_bytes > 0 and sess.total_bytes != total:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Total upload size mismatch ({total} vs {sess.total_bytes}).",
            )
        sess.total_bytes = total
        sess.file_ext = ext

        expected_offset = int(sess.received_bytes)
        if sess.status == "completed" or expected_offset >= total:
            return JSONResponse(
                status_code=status.HTTP_409_CONFLICT,
                content={
                    "detail": "Upload already completed.",
                    "expected_offset": expected_offset,
                    "received_bytes": expected_offset,
                    "total_bytes": total,
                },
            )

        if start != expected_offset:
            return JSONResponse(
                status_code=status.HTTP_409_CONFLICT,
                content={
                    "detail": (
                        f"Offset mismatch: expected byte {expected_offset}, got {start}."
                    ),
                    "expected_offset": expected_offset,
                    "received_bytes": expected_offset,
                    "total_bytes": total,
                },
            )

        dest_path = safe_audio_path(settings.storage_path, meeting.id, ext)
        write_chunk_at_expected_offset(dest_path, expected_offset, chunk_bytes)

        new_received = end + 1
        sess.received_bytes = new_received
        meeting.audio_path = str(dest_path)
        complete = new_received == total

        if complete:
            sess.status = "completed"
            if auto_process:
                meeting.status = "queued"
                meeting.progress_percent = 5
                meeting.status_message = "Upload complete. Queued for transcription."
                should_enqueue = True
            else:
                meeting.status = "uploaded"
                meeting.progress_percent = 5
                meeting.status_message = "Audio uploaded; ready to process."
        else:
            meeting.status = "uploading"
            meeting.progress_percent = 0
            meeting.status_message = f"Uploading audio ({new_received}/{total} bytes)."

        db.commit()

    if should_enqueue:
        worker.enqueue(meeting_id)

    logger.info(
        "Chunk uploaded meeting_id=%s bytes=%d/%d complete=%s",
        meeting_id,
        new_received,
        total,
        complete,
    )
    return UploadChunkResponse(
        meeting_id=meeting_id,
        upload_session_id=sess.id,
        received_bytes=new_received,
        total_bytes=total,
        complete=complete,
        status=meeting.status,
    )


@router.post("/{meeting_id}/process", response_model=MeetingStatusResponse)
def process_meeting(
    meeting_id: str,
    _token: Annotated[str, Depends(require_bearer_token)],
    db: Annotated[Session, Depends(get_db)],
    worker: Annotated[TranscriptionWorkerManager, Depends(get_worker)],
    payload: Annotated[ProcessRequest | None, Body()] = None,
) -> MeetingStatusResponse:
    meeting = _load_meeting_full(db, meeting_id)
    if meeting is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Meeting not found"
        )
    if not meeting.upload_session or meeting.upload_session.status != "completed":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Audio upload is not complete yet.",
        )

    if payload is not None:
        if payload.language_hint is not None:
            meeting.language_hint = payload.language_hint
        if payload.glossary is not None:
            meeting.glossary = payload.glossary
        if payload.silence_ranges is not None:
            meeting.silence_ranges_json = json.dumps(
                [r.model_dump() for r in payload.silence_ranges]
            )

    if meeting.status in {"queued", "transcribing"}:
        db.commit()
        worker.enqueue(meeting.id)
        return MeetingStatusResponse(
            meeting_id=meeting.id,
            status=meeting.status,
            progress_percent=meeting.progress_percent,
            message=meeting.status_message or "Transcription in progress.",
            error_message=meeting.error_message,
        )

    meeting.status = "queued"
    meeting.progress_percent = 5
    meeting.status_message = "Queued for transcription."
    meeting.error_message = None
    db.commit()

    worker.enqueue(meeting.id)
    return MeetingStatusResponse(
        meeting_id=meeting.id,
        status=meeting.status,
        progress_percent=meeting.progress_percent,
        message=meeting.status_message,
        error_message=None,
    )


@router.get("/{meeting_id}/status", response_model=MeetingStatusResponse)
def get_meeting_status(
    meeting_id: str,
    _token: Annotated[str, Depends(require_bearer_token)],
    db: Annotated[Session, Depends(get_db)],
) -> MeetingStatusResponse:
    meeting = db.get(Meeting, meeting_id)
    if meeting is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Meeting not found"
        )
    return MeetingStatusResponse(
        meeting_id=meeting.id,
        status=meeting.status,
        progress_percent=meeting.progress_percent,
        message=meeting.status_message,
        error_message=meeting.error_message,
    )


@router.get("/{meeting_id}", response_model=MeetingResponse)
def get_meeting_detail(
    meeting_id: str,
    _token: Annotated[str, Depends(require_bearer_token)],
    db: Annotated[Session, Depends(get_db)],
) -> Meeting:
    meeting = _load_meeting_full(db, meeting_id)
    if meeting is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Meeting not found"
        )
    return meeting


@router.delete("/{meeting_id}")
def delete_meeting(
    meeting_id: str,
    _token: Annotated[str, Depends(require_bearer_token)],
    db: Annotated[Session, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict[str, str | bool]:
    lock = get_meeting_upload_lock(meeting_id)
    with lock:
        meeting = db.get(Meeting, meeting_id)
        if meeting is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Meeting not found"
            )
        audio_path = meeting.audio_path
        db.delete(meeting)
        db.commit()
    delete_audio_file(settings.storage_path, audio_path)
    logger.info("Deleted meeting_id=%s", meeting_id)
    return {"deleted": True, "meeting_id": meeting_id}
