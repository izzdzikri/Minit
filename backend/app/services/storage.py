"""Safe, locked chunked audio storage with sanitized UUID filenames."""

from __future__ import annotations

import os
import re
import threading
from pathlib import Path

from fastapi import HTTPException, status

_RANGE_RE = re.compile(r"^bytes\s+(\d+)-(\d+)/(\d+)$", re.IGNORECASE)
_UUID_SAFE_RE = re.compile(r"^[a-fA-F0-9\-]{8,64}$")

# Lock table to serialize concurrent chunk writes for the same meeting ID.
_LOCKS_GUARD = threading.Lock()
_MEETING_LOCKS: dict[str, threading.Lock] = {}


def get_meeting_upload_lock(meeting_id: str) -> threading.Lock:
    with _LOCKS_GUARD:
        lock = _MEETING_LOCKS.get(meeting_id)
        if lock is None:
            lock = threading.Lock()
            _MEETING_LOCKS[meeting_id] = lock
        return lock


def sanitize_extension(raw: str | None, allowed: frozenset[str]) -> str:
    """Extract and validate an audio extension against the config allowlist.

    Never preserves any user-supplied directory or base filename.
    """
    if not raw:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Audio file type is required (m4a, aac, mp3, wav, webm).",
        )
    candidate = raw.strip().lower()
    if "." in candidate:
        candidate = candidate.rsplit(".", 1)[-1]
    candidate = re.sub(r"[^a-z0-9]", "", candidate)
    if not candidate or candidate not in allowed:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported audio type '.{candidate or '?'}'. Allowed: {', '.join(sorted(allowed))}",
        )
    return candidate


def safe_audio_path(storage_root: Path, meeting_id: str, ext: str) -> Path:
    """Build `<storage_root>/audio/<meeting_id>.<ext>` preventing path escape."""
    if not _UUID_SAFE_RE.match(meeting_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid meeting identifier",
        )
    audio_dir = (storage_root / "audio").resolve()
    audio_dir.mkdir(parents=True, exist_ok=True)
    target = (audio_dir / f"{meeting_id}.{ext}").resolve()
    if target.parent != audio_dir:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid target audio path",
        )
    return target


def parse_content_range(
    header_value: str | None,
    max_upload_bytes: int,
    max_chunk_bytes: int,
) -> tuple[int, int, int]:
    """Parse RFC 9110 `bytes <start>-<end>/<total>` Content-Range header."""
    if not header_value:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Content-Range header is required (bytes <start>-<end>/<total>).",
        )
    m = _RANGE_RE.match(header_value.strip())
    if not m:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid Content-Range header format; expected 'bytes <start>-<end>/<total>'.",
        )
    start = int(m.group(1))
    end = int(m.group(2))
    total = int(m.group(3))

    if total <= 0 or total > max_upload_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail=f"Upload size exceeds limit ({max_upload_bytes} bytes).",
        )
    if start < 0 or end < start or end >= total:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid byte range bounds in Content-Range.",
        )
    chunk_len = end - start + 1
    if chunk_len > max_chunk_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail=f"Chunk size exceeds limit ({max_chunk_bytes} bytes).",
        )
    return start, end, total


def write_chunk_at_expected_offset(
    dest_path: Path,
    expected_offset: int,
    data: bytes,
) -> None:
    """Truncate any stale partial tail to `expected_offset` and append `data` atomically."""
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    mode = "r+b" if dest_path.exists() else "w+b"
    with dest_path.open(mode) as fh:
        fh.truncate(expected_offset)
        fh.seek(expected_offset)
        fh.write(data)
        fh.flush()
        os.fsync(fh.fileno())


def delete_audio_file(storage_root: Path, audio_path_str: str | None) -> None:
    """Delete stored audio safely if it lies under `storage_root`."""
    if not audio_path_str:
        return
    try:
        root_resolved = storage_root.resolve()
        candidate = Path(audio_path_str).resolve()
        if candidate.is_relative_to(root_resolved) and candidate.is_file():
            candidate.unlink()
    except OSError:
        pass
