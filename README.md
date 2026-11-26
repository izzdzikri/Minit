# Minit

Minit is an Android-first meeting and lecture recorder designed to capture reliable long-form audio—including mixed English/Malay (Manglish) speech—and produce timestamped transcripts via a self-hosted FastAPI + `faster-whisper` backend, ready for export or later AI summarization.

## Tech Stack
- **Mobile (Android):** Flutter, Dart, Material 3 (custom light/dark design tokens, bundled `Inter` & `Source Serif 4` fonts), `flutter_riverpod`, `go_router`, `drift` (SQLite), `record`, `flutter_foreground_task`, `just_audio`, `audio_session`, `flutter_secure_storage`, `connectivity_plus`, `http`, `share_plus`, `permission_handler`, `device_info_plus`
- **Backend:** Python 3.12, FastAPI, SQLAlchemy + Alembic (SQLite dev / PostgreSQL-ready), `faster-whisper` (`medium`, `int8`, CPU `ms` default, VAD + anti-hallucination + repetition-loop retry), `ffmpeg`, `pytest`, `ruff`

## Quick Start (One Command Each)

### 1. First-time Backend Setup (Python 3.12 + `.env`)
> Never commit `.env` or recorded audio files. Replace the sample token before starting.

```bash
cd backend
python3.12 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env
# Generate a strong bearer token and set API_TOKEN in backend/.env:
python3 -c "import secrets; print('API_TOKEN=' + secrets.token_urlsafe(32))"
.venv/bin/alembic upgrade head
```

### Run Backend
```bash
cd backend && .venv/bin/uvicorn app.main:get_asgi_app --factory --host 0.0.0.0 --port 8000
```

### Run Android App (Debug Build)
```bash
cd app && flutter run --debug -d <device_id>
```

## Connecting Your Phone to the Local Backend

1. **Enter your token in Minit Settings:** Copy the `API_TOKEN` from `backend/.env` into **Settings -> Transcription server -> API token** (stored in Android Keystore via `flutter_secure_storage`).
2. **Option A — USB via `adb reverse` (simplest on the same desk):**
   ```bash
   adb reverse tcp:8000 tcp:8000
   ```
   Keep **Server URL** set to `http://localhost:8000` in the app, then tap **Test connection**. (Re-run `adb reverse tcp:8000 tcp:8000` if you unplug and reconnect USB.)
3. **Option B — Same Wi-Fi / LAN:**
   Find your PC's local IP (`ip -4 addr` on Linux), ensure TCP port `8000` is open in your firewall (`sudo firewall-cmd --add-port=8000/tcp` or `ufw allow 8000/tcp`), and set **Server URL** in the app to `http://<PC_LAN_IP>:8000`.
4. **Option C — Remote Access via Tailscale Serve (HTTPS, works on Release builds):**
   If you want to upload and transcribe away from home Wi-Fi (or use a release APK that requires `https://`), run Tailscale on both your backend PC and your phone and expose port `8000` over Tailscale HTTPS (nothing is installed automatically; install Tailscale yourself first):
   ```bash
   tailscale serve --bg 8000
   tailscale serve status
   ```
   Copy the HTTPS MagicDNS URL printed by `tailscale serve status` (for example, `https://<machine>.<tailnet>.ts.net`, with **no** `:8000` suffix).
   - **What changes in the app:** Open **Settings -> Transcription server -> Server URL**, change it from `http://localhost:8000` to `https://<machine>.<tailnet>.ts.net`, keep your `API_TOKEN` from `backend/.env`, and tap **Test connection**. When you next upload or tap **Transcribe**, the one-time upload consent dialog will ask you to confirm the new URL.
   - To stop exposing it later: `tailscale serve --https=443 off`.
5. **Debug vs. Release Security:**
   Only debug builds (`flutter run --debug` / debug APK) allow plain `http://` traffic (`app/android/app/src/debug/res/xml/network_security_config.xml`). Release builds enforce `https://` only (`cleartextTrafficPermitted="false"`). Tailscale Serve (`https://...ts.net`), Caddy, or Nginx TLS satisfies release builds cleanly without enabling cleartext HTTP.

## Tests & Linting

```bash
# Backend lint, unit/API tests, and real audio end-to-end test
cd backend
.venv/bin/ruff check app alembic scripts
.venv/bin/pytest -v
.venv/bin/python -u scripts/e2e.py

# App static analysis and unit/widget tests
cd app
flutter analyze
flutter test
```

## Current Status
- **Phase 2 (`phase-2-backend`):** Local FastAPI + `faster-whisper` (`medium` `int8`, `ms` default) transcription backend with chunked resumable HTTP uploads, silence-aware 15-minute chunk splitting with 2-second overlap deduplication, anti-hallucination thresholds + loop retry/flagging, vocabulary glossary hints (`initial_prompt`), Drift v2 `UploadQueue` + Wi-Fi-only / connectivity resume, Android Keystore API token storage, local `"Transcript ready"` notifications, and visual low-confidence/loop markings (without hiding any text). Keeps 16 kHz mono AAC **32 kbps** after controlled WER ablation against `ref_clip1.txt`. LLM summaries and speaker diarization remain deferred to later phases.
- **Phase 1 (`phase-1-ui`):** Minit branding (`com.izzdzikri.minit`), adaptive launcher icons & Android 12+ splash screens, Drift SQLite database & full-text search, Library / Search / Record / Meeting Detail / Settings shell, live 10 Hz waveform ring buffer & replay scrubbing, Markdown/clipboard/share export, predictive back navigation stack, and profile-verified 60 fps UI responsiveness.
- **Phase 0 (`main`, tagged `phase-0-spike`):** Background recording spike — foreground service (`microphone` type), 16 kHz mono AAC 30-second segments, native `.m4a` merging, interruption & call auto-resume, Force mode, low-storage auto-stop, and local playback.

## Privacy Note
Recorded audio files (`.m4a`, `.aac`, `.wav`, `.mp3`, and `pending/` segments), local SQLite storage (`backend/storage/`), benchmark outputs (`backend/benchmark_out/`), and `backend/.env` are stored locally and gitignored. Never commit credentials or personal meeting audio.
