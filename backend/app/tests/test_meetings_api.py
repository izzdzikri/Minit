"""API integration tests covering auth, idempotency, resume, validation, and recovery."""

from __future__ import annotations

import time
from datetime import UTC, datetime
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.db import create_session_factory
from app.main import create_app
from app.models import Meeting, UploadSession
from app.services.transcribe import CloudProvider

from .conftest import FakeTranscriptionProvider


def _wait_for_status(
    client: TestClient,
    headers: dict[str, str],
    meeting_id: str,
    wanted: set[str],
    timeout_sec: float = 5.0,
) -> dict:
    deadline = time.monotonic() + timeout_sec
    last_body: dict = {}
    while time.monotonic() < deadline:
        resp = client.get(f"/api/meetings/{meeting_id}/status", headers=headers)
        assert resp.status_code == 200
        last_body = resp.json()
        if last_body["status"] in wanted:
            return last_body
        time.sleep(0.05)
    raise AssertionError(f"Timed out waiting for {wanted}; last={last_body}")


def test_refuses_to_start_with_placeholder_token(tmp_path: Path) -> None:
    bad_settings = Settings(
        API_TOKEN="change-me-replace-with-random-token",
        DATABASE_URL=f"sqlite:///{tmp_path / 'bad.db'}",
        STORAGE_DIR=str(tmp_path / "storage"),
    )
    with pytest.raises(RuntimeError, match="non-placeholder API_TOKEN"):
        create_app(settings_override=bad_settings)


def test_auth_rejection_and_cors_off(
    test_settings: Settings,
    auth_headers: dict[str, str],
) -> None:
    app = create_app(
        settings_override=test_settings,
        provider_override=FakeTranscriptionProvider(),
    )
    with TestClient(app) as client:
        assert client.get("/api/health").status_code == 401
        assert (
            client.get(
                "/api/health", headers={"Authorization": "Bearer wrong-token"}
            ).status_code
            == 401
        )
        assert (
            client.post(
                "/api/meetings",
                json={"client_meeting_id": "m1", "title": "Test"},
            ).status_code
            == 401
        )

        ok = client.get(
            "/api/health",
            headers={**auth_headers, "Origin": "https://evil.example.com"},
        )
        assert ok.status_code == 200
        assert "access-control-allow-origin" not in ok.headers


def test_idempotent_create_meeting(
    test_settings: Settings,
    auth_headers: dict[str, str],
) -> None:
    app = create_app(
        settings_override=test_settings,
        provider_override=FakeTranscriptionProvider(),
    )
    payload = {
        "client_meeting_id": "client-uuid-001",
        "title": "Sprint Planning",
        "language_hint": "ms",
        "glossary": "ChatGPT, benchmark",
    }
    with TestClient(app) as client:
        first = client.post("/api/meetings", json=payload, headers=auth_headers)
        assert first.status_code == 201
        second = client.post("/api/meetings", json=payload, headers=auth_headers)
        assert second.status_code == 200
        assert second.json()["id"] == first.json()["id"]
        assert second.json()["client_meeting_id"] == "client-uuid-001"


def test_resumable_upload_interrupt_wrong_offset_and_transcribe(
    test_settings: Settings,
    auth_headers: dict[str, str],
) -> None:
    fake = FakeTranscriptionProvider()
    app = create_app(settings_override=test_settings, provider_override=fake)
    audio_bytes = b"FAKE_M4A_HEADER_" + (b"0123456789ABCDEF" * 300)
    total = len(audio_bytes)
    mid = total // 2

    with TestClient(app) as client:
        created = client.post(
            "/api/meetings",
            json={
                "client_meeting_id": "resume-1",
                "title": "Resume Check",
                "language_hint": "auto",
                "glossary": "benchmark, decision tree",
                "total_bytes": total,
                "file_ext": "m4a",
            },
            headers=auth_headers,
        ).json()
        meeting_id = created["id"]

        # Chunk 1 with adversarial client filename (must NOT leak onto disk)
        c1 = client.put(
            f"/api/meetings/{meeting_id}/upload",
            content=audio_bytes[:mid],
            headers={
                **auth_headers,
                "Content-Range": f"bytes 0-{mid - 1}/{total}",
                "X-Filename": "../../../../etc/passwd.m4a",
                "Content-Type": "audio/mp4",
            },
        )
        assert c1.status_code == 200
        assert c1.json()["received_bytes"] == mid
        assert c1.json()["complete"] is False

        # Wrong offset must be rejected with 409 and preserve expected offset
        wrong = client.put(
            f"/api/meetings/{meeting_id}/upload",
            content=audio_bytes[:100],
            headers={
                **auth_headers,
                "Content-Range": f"bytes 0-99/{total}",
                "X-File-Extension": "m4a",
            },
        )
        assert wrong.status_code == 409
        assert wrong.json()["expected_offset"] == mid

        # HEAD and GET report exact offset to resume from
        head_resp = client.head(f"/api/meetings/{meeting_id}/upload", headers=auth_headers)
        assert head_resp.status_code == 200
        assert head_resp.headers["Upload-Offset"] == str(mid)

        get_off = client.get(f"/api/meetings/{meeting_id}/upload", headers=auth_headers)
        assert get_off.status_code == 200
        assert get_off.json()["received_bytes"] == mid

        # Resume final chunk
        c2 = client.put(
            f"/api/meetings/{meeting_id}/upload",
            content=audio_bytes[mid:],
            headers={
                **auth_headers,
                "Content-Range": f"bytes {mid}-{total - 1}/{total}",
                "X-File-Extension": "m4a",
            },
        )
        assert c2.status_code == 200
        assert c2.json()["complete"] is True
        assert c2.json()["status"] == "queued"

        # Wait for worker to finish
        final_status = _wait_for_status(client, auth_headers, meeting_id, {"ready"})
        assert final_status["progress_percent"] == 100

        detail = client.get(f"/api/meetings/{meeting_id}", headers=auth_headers)
        assert detail.status_code == 200
        data = detail.json()
        assert data["status"] == "ready"
        assert data["detected_language"] == "ms"
        assert len(data["segments"]) == 2
        assert data["segments"][0]["speaker_label"] == "Speaker 1"
        assert data["segments"][0]["avg_logprob"] == -0.28
        assert data["segments"][1]["avg_logprob"] == -0.65

        # Audio file saved strictly under <storage>/audio/<uuid>.m4a
        expected_file = test_settings.storage_path / "audio" / f"{meeting_id}.m4a"
        assert expected_file.is_file()
        assert expected_file.read_bytes() == audio_bytes

        # Delete removes DB rows and audio file
        deleted = client.delete(f"/api/meetings/{meeting_id}", headers=auth_headers)
        assert deleted.status_code == 200
        assert not expected_file.exists()
        assert (
            client.get(f"/api/meetings/{meeting_id}", headers=auth_headers).status_code
            == 404
        )


def test_status_uploaded_then_manual_process_and_failed_transition(
    test_settings: Settings,
    auth_headers: dict[str, str],
) -> None:
    failing = FakeTranscriptionProvider(should_fail=True)
    app = create_app(settings_override=test_settings, provider_override=failing)
    payload = b"1234567890" * 10
    with TestClient(app) as client:
        meeting_id = client.post(
            "/api/meetings",
            json={"client_meeting_id": "manual-1", "title": "Manual Trigger"},
            headers=auth_headers,
        ).json()["id"]

        up = client.put(
            f"/api/meetings/{meeting_id}/upload?auto_process=false",
            content=payload,
            headers={
                **auth_headers,
                "Content-Range": f"bytes 0-{len(payload) - 1}/{len(payload)}",
                "X-File-Extension": "wav",
            },
        )
        assert up.status_code == 200
        assert up.json()["status"] == "uploaded"

        proc = client.post(
            f"/api/meetings/{meeting_id}/process",
            json={
                "language_hint": "ms",
                "silence_ranges": [{"start_sec": 1.0, "end_sec": 3.5}],
            },
            headers=auth_headers,
        )
        assert proc.status_code == 200
        assert proc.json()["status"] in {"queued", "transcribing", "failed"}

        end_status = _wait_for_status(client, auth_headers, meeting_id, {"failed"})
        assert "Simulated provider crash" in (end_status["error_message"] or "")


def test_size_type_and_rate_limit_validation(
    tmp_path: Path,
) -> None:
    strict_settings = Settings(
        API_TOKEN="strict-token-12345",
        DATABASE_URL=f"sqlite:///{tmp_path / 'strict.db'}",
        STORAGE_DIR=str(tmp_path / "storage"),
        MAX_UPLOAD_BYTES=1024,
        MAX_REQUEST_BODY_BYTES=1024,
        UPLOAD_RATE_LIMIT_REQUESTS=2,
        UPLOAD_RATE_LIMIT_WINDOW_SEC=60,
    )
    headers = {"Authorization": f"Bearer {strict_settings.API_TOKEN}"}
    app = create_app(
        settings_override=strict_settings,
        provider_override=FakeTranscriptionProvider(),
    )
    with TestClient(app) as client:
        too_big = client.post(
            "/api/meetings",
            json={
                "client_meeting_id": "big-1",
                "title": "Too Big",
                "total_bytes": 5000,
                "file_ext": "m4a",
            },
            headers=headers,
        )
        assert too_big.status_code == 413

        bad_type = client.post(
            "/api/meetings",
            json={
                "client_meeting_id": "bad-type",
                "title": "Bad Type",
                "total_bytes": 500,
                "file_ext": "exe",
            },
            headers=headers,
        )
        assert bad_type.status_code == 415

        meeting_id = client.post(
            "/api/meetings",
            json={"client_meeting_id": "ok-rate", "title": "Rate Test"},
            headers=headers,
        ).json()["id"]

        # 2 allowed chunks, 3rd hits 429 rate limit
        r1 = client.put(
            f"/api/meetings/{meeting_id}/upload",
            content=b"a" * 100,
            headers={**headers, "Content-Range": "bytes 0-99/400", "X-File-Extension": "m4a"},
        )
        assert r1.status_code == 200
        r2 = client.put(
            f"/api/meetings/{meeting_id}/upload",
            content=b"b" * 100,
            headers={**headers, "Content-Range": "bytes 100-199/400", "X-File-Extension": "m4a"},
        )
        assert r2.status_code == 200
        r3 = client.put(
            f"/api/meetings/{meeting_id}/upload",
            content=b"c" * 100,
            headers={**headers, "Content-Range": "bytes 200-299/400", "X-File-Extension": "m4a"},
        )
        assert r3.status_code == 429
        assert "Retry-After" in r3.headers


def test_crash_recovery_requeues_stuck_transcribing_job_and_delete_audio_flag(
    tmp_path: Path,
) -> None:
    cfg = Settings(
        API_TOKEN="recovery-token-999",
        DATABASE_URL=f"sqlite:///{tmp_path / 'recover.db'}",
        STORAGE_DIR=str(tmp_path / "storage"),
        DELETE_AUDIO_AFTER_TRANSCRIBE=True,
    )
    headers = {"Authorization": f"Bearer {cfg.API_TOKEN}"}

    # Seed DB directly with a job stuck mid-transcription ("transcribing") before server boot.
    audio_dir = cfg.storage_path / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)
    audio_file = audio_dir / "stuck-meeting-1.m4a"
    audio_file.write_bytes(b"VALID_DUMMY_BYTES")

    app_pre = create_app(settings_override=cfg, provider_override=FakeTranscriptionProvider())
    _, factory = create_session_factory(cfg)
    with factory() as db:
        now = datetime.now(UTC)
        m = Meeting(
            id="stuck-meeting-1",
            client_meeting_id="client-stuck-1",
            title="Crashed Mid Job",
            language_hint="ms",
            status="transcribing",
            progress_percent=42,
            status_message="Transcribing...",
            audio_path=str(audio_file),
            created_at=now,
            updated_at=now,
        )
        db.add(m)
        db.add(
            UploadSession(
                meeting_id="stuck-meeting-1",
                file_ext="m4a",
                total_bytes=17,
                received_bytes=17,
                status="completed",
            )
        )
        db.commit()
    assert app_pre is not None

    # Reboot app: lifespan must automatically recover "transcribing" -> "queued" -> "ready".
    app_boot = create_app(
        settings_override=cfg,
        provider_override=FakeTranscriptionProvider(),
    )
    with TestClient(app_boot) as client:
        st = _wait_for_status(client, headers, "stuck-meeting-1", {"ready"})
        assert st["status"] == "ready"
        detail = client.get("/api/meetings/stuck-meeting-1", headers=headers).json()
        assert len(detail["segments"]) == 2
        # DELETE_AUDIO_AFTER_TRANSCRIBE=True must remove the file once ready
        assert not audio_file.exists()


def test_cloud_provider_stub_raises_not_implemented(tmp_path: Path) -> None:
    provider = CloudProvider()
    with pytest.raises(NotImplementedError):
        provider.transcribe_audio(tmp_path / "x.m4a", language_hint="ms")
