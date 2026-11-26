"""Bearer token authentication dependency.

Phase 2 uses a single shared API_TOKEN from `.env`.
Phase 4 replaces this with real user accounts and per-user tokens.
"""

from __future__ import annotations

import hmac
from typing import Annotated

from fastapi import Depends, Header, HTTPException, status

from ..config import Settings, get_settings


def require_bearer_token(
    settings: Annotated[Settings, Depends(get_settings)],
    authorization: Annotated[str | None, Header()] = None,
) -> str:
    """Validate Authorization: Bearer <token> in constant time."""
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )
    parts = authorization.split(" ", 1)
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Authorization scheme; expected Bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    provided = parts[1].strip()
    expected = settings.API_TOKEN.strip()
    if not provided or not expected or not hmac.compare_digest(provided, expected):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return provided
