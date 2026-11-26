"""In-memory per-token sliding-window rate limiter for uploads."""

from __future__ import annotations

import hashlib
import threading
import time
from collections import defaultdict, deque

from fastapi import HTTPException, status


class UploadRateLimiter:
    """Thread-safe sliding window rate limiter keyed by hashed bearer token."""

    def __init__(self, max_requests: int, window_seconds: int) -> None:
        self._max_requests = max(1, max_requests)
        self._window_seconds = max(1, window_seconds)
        self._lock = threading.Lock()
        self._hits: dict[str, deque[float]] = defaultdict(deque)

    def configure(self, max_requests: int, window_seconds: int) -> None:
        with self._lock:
            self._max_requests = max(1, max_requests)
            self._window_seconds = max(1, window_seconds)

    def reset(self) -> None:
        with self._lock:
            self._hits.clear()

    def check_and_consume(self, token: str) -> None:
        key = hashlib.sha256(token.encode("utf-8")).hexdigest()[:16]
        now = time.monotonic()
        cutoff = now - self._window_seconds
        with self._lock:
            bucket = self._hits[key]
            while bucket and bucket[0] <= cutoff:
                bucket.popleft()
            if len(bucket) >= self._max_requests:
                retry_after = max(1, int(self._window_seconds - (now - bucket[0])) + 1)
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Upload rate limit exceeded. Retry shortly.",
                    headers={"Retry-After": str(retry_after)},
                )
            bucket.append(now)


upload_rate_limiter = UploadRateLimiter(max_requests=600, window_seconds=60)
