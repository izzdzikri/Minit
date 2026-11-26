"""End-to-end backend smoke test: chunked upload -> mid-upload drop -> resume -> poll -> transcript.

Usage:
    backend/.venv/bin/python backend/scripts/e2e.py [--file <audio_path>] [--url http://127.0.0.1:8000] [--token ...]
"""

from __future__ import annotations

import argparse
import os
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import httpx

BACKEND_ROOT = Path(__file__).resolve().parents[1]


def _pick_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return int(s.getsockname()[1])


def _default_fixture(tmp_dir: Path) -> Path:
    candidates = [
        BACKEND_ROOT / "benchmark_out" / "bitrate_ab" / "clip1_48k.m4a",
        BACKEND_ROOT / "benchmark_out" / "prepared_clips" / "clip1_5min_app.m4a",
    ]
    for cand in candidates:
        if cand.is_file():
            trimmed = tmp_dir / "e2e_clip_25s.m4a"
            subprocess.run(
                [
                    "ffmpeg",
                    "-y",
                    "-hide_banner",
                    "-loglevel",
                    "error",
                    "-i",
                    str(cand),
                    "-t",
                    "25",
                    "-c:a",
                    "copy",
                    str(trimmed),
                ],
                check=True,
            )
            return trimmed
    raise RuntimeError(
        "No local audio fixture found. Pass --file <path/to/audio.m4a> explicitly."
    )


def run_e2e(
    *,
    audio_file: Path,
    base_url: str,
    token: str,
    chunk_bytes: int,
    language_hint: str,
    glossary: str | None,
) -> int:
    data = audio_file.read_bytes()
    total = len(data)
    ext = audio_file.suffix.lstrip(".").lower() or "m4a"
    headers = {"Authorization": f"Bearer {token}"}

    print(f"1. Checking /api/health at {base_url}...")
    with httpx.Client(base_url=base_url, timeout=30.0) as client:
        h = client.get("/api/health", headers=headers)
        h.raise_for_status()
        print("   Health:", h.json())

        client_id = f"e2e-{int(time.time())}"
        print(f"2. Creating meeting (client_meeting_id={client_id}, total_bytes={total})...")
        create_resp = client.post(
            "/api/meetings",
            headers=headers,
            json={
                "client_meeting_id": client_id,
                "title": f"E2E Check {audio_file.name}",
                "language_hint": language_hint,
                "glossary": glossary,
                "total_bytes": total,
                "file_ext": ext,
            },
        )
        create_resp.raise_for_status()
        meeting = create_resp.json()
        meeting_id = meeting["id"]
        print(f"   Created meeting_id={meeting_id}")

    # Phase A: upload first chunk, then deliberately close/drop connection halfway!
    first_end = min(chunk_bytes, max(1, total // 2))
    print(f"3. Uploading bytes 0..{first_end - 1} of {total}, then dropping connection...")
    with httpx.Client(base_url=base_url, timeout=30.0) as dropped_client:
        r0 = dropped_client.put(
            f"/api/meetings/{meeting_id}/upload",
            headers={
                **headers,
                "Content-Range": f"bytes 0-{first_end - 1}/{total}",
                "X-File-Extension": ext,
            },
            content=data[:first_end],
        )
        r0.raise_for_status()
        print("   Uploaded part 1:", r0.json())
    print("   Simulated connection drop complete.")

    # Phase B: reconnect, ask HEAD /upload for current server offset, and resume remaining bytes!
    print("4. Reconnecting -> querying HEAD /upload for resume offset...")
    with httpx.Client(base_url=base_url, timeout=60.0) as resume_client:
        head = resume_client.head(f"/api/meetings/{meeting_id}/upload", headers=headers)
        head.raise_for_status()
        offset = int(head.headers["Upload-Offset"])
        print(f"   Server reported Upload-Offset={offset} / {total}")
        assert offset == first_end, f"Expected offset {first_end}, got {offset}"

        while offset < total:
            end = min(offset + chunk_bytes, total)
            r = resume_client.put(
                f"/api/meetings/{meeting_id}/upload",
                headers={
                    **headers,
                    "Content-Range": f"bytes {offset}-{end - 1}/{total}",
                    "X-File-Extension": ext,
                },
                content=data[offset:end],
            )
            r.raise_for_status()
            body = r.json()
            offset = int(body["received_bytes"])
            print(f"   Chunk ACK -> received={offset}/{total} status={body['status']}")

        print("5. Polling /status until ready...")
        while True:
            st_resp = resume_client.get(
                f"/api/meetings/{meeting_id}/status", headers=headers
            )
            st_resp.raise_for_status()
            st = st_resp.json()
            print(
                f"   status={st['status']} progress={st['progress_percent']}% ({st['message']})"
            )
            if st["status"] == "ready":
                break
            if st["status"] == "failed":
                print(f"   FAILED: {st.get('error_message')}", file=sys.stderr)
                return 1
            time.sleep(1.0)

        print("6. Fetching final transcript:")
        detail = resume_client.get(f"/api/meetings/{meeting_id}", headers=headers)
        detail.raise_for_status()
        result = detail.json()
        print(
            f"   detected_language={result.get('detected_language')} "
            f"duration={result.get('duration_sec')}s segments={len(result['segments'])}"
        )
        for seg in result["segments"]:
            print(
                f"   [{seg['start_sec']:06.2f} -> {seg['end_sec']:06.2f}] "
                f"{seg['speaker_label']} (lp={seg.get('avg_logprob')}): {seg['text']}"
            )
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="E2E chunked resume + transcribe test.")
    parser.add_argument("--file", type=Path, default=None, help="Audio file to upload.")
    parser.add_argument("--url", type=str, default=None, help="Existing server base URL.")
    parser.add_argument("--token", type=str, default="e2e-local-secret-token")
    parser.add_argument("--chunk-bytes", type=int, default=65536)
    parser.add_argument("--language", type=str, default="ms")
    parser.add_argument(
        "--glossary",
        type=str,
        default="ChatGPT, benchmark, synthetic data, missing values, imbalance",
    )
    parser.add_argument("--model", type=str, default="medium")
    args = parser.parse_args(argv)

    with tempfile.TemporaryDirectory(prefix="minit_e2e_") as td:
        tmp_dir = Path(td)
        audio_path = args.file.expanduser().resolve() if args.file else _default_fixture(tmp_dir)
        if args.url:
            return run_e2e(
                audio_file=audio_path,
                base_url=args.url.rstrip("/"),
                token=args.token,
                chunk_bytes=args.chunk_bytes,
                language_hint=args.language,
                glossary=args.glossary,
            )

        port = _pick_free_port()
        env = os.environ.copy()
        env.update(
            {
                "API_TOKEN": args.token,
                "DATABASE_URL": f"sqlite:///{tmp_dir / 'e2e.db'}",
                "STORAGE_DIR": str(tmp_dir / "storage"),
                "WHISPER_MODEL_SIZE": args.model,
                "WHISPER_COMPUTE_TYPE": "int8",
                "WHISPER_LANGUAGE_DEFAULT": args.language,
            }
        )
        server_proc = subprocess.Popen(
            [
                str(BACKEND_ROOT / ".venv" / "bin" / "uvicorn"),
                "app.main:get_asgi_app",
                "--factory",
                "--host",
                "127.0.0.1",
                "--port",
                str(port),
            ],
            cwd=str(BACKEND_ROOT),
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        base_url = f"http://127.0.0.1:{port}"
        try:
            deadline = time.monotonic() + 20.0
            ready = False
            while time.monotonic() < deadline:
                try:
                    r = httpx.get(
                        f"{base_url}/api/health",
                        headers={"Authorization": f"Bearer {args.token}"},
                        timeout=1.0,
                    )
                    if r.status_code == 200:
                        ready = True
                        break
                except httpx.HTTPError:
                    time.sleep(0.2)
            if not ready:
                raise RuntimeError("E2E ephemeral uvicorn server did not start in time.")

            return run_e2e(
                audio_file=audio_path,
                base_url=base_url,
                token=args.token,
                chunk_bytes=args.chunk_bytes,
                language_hint=args.language,
                glossary=args.glossary,
            )
        finally:
            server_proc.terminate()
            try:
                server_proc.wait(timeout=5.0)
            except subprocess.TimeoutExpired:
                server_proc.kill()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
