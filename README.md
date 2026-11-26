# Minit

Minit is an Android-first meeting and lecture recorder designed to capture reliable long-form audio—including mixed English/Malay (Manglish) speech—and produce timestamped, speaker-labeled transcripts, AI summaries, decisions, and action items.

## Tech Stack
- **Mobile (Android):** Flutter, Dart, Material 3 (custom light/dark design tokens, bundled `Inter` & `Source Serif 4` fonts), `flutter_riverpod`, `go_router`, `drift` (SQLite), `record`, `flutter_foreground_task`, `just_audio`, `audio_session`, `share_plus`, `permission_handler`, `device_info_plus`
- **Backend (upcoming — Phase 2):** Python FastAPI, SQLAlchemy, PostgreSQL, faster-whisper, pyannote.audio

## How to Run
```bash
cd app
flutter pub get
flutter run -d <device_id>
```

## Current Status
- **Phase 1 (`phase-1-ui`, active default branch):** Minit branding (`com.izzdzikri.minit`), adaptive/themed launcher icons & Android 12+ light/dark splash screens, Drift local SQLite database & full-text search, Library / Search / Record / Meeting Detail / Settings shell, live 10 Hz waveform ring buffer & replay scrubbing, Markdown/clipboard/share export, predictive back navigation stack, and profile-verified 60 fps UI responsiveness (`22` unit/widget tests passing).
- **Phase 0 (`main`, tagged `phase-0-spike`):** Background recording spike — foreground service (`microphone` type), 16 kHz mono AAC capture in continuous 30-second disk segments, native `.m4a` merging, interruption handling (Normal mode with post-call auto-resume + Force mode with silence markers), low-storage auto-stop, and local playback.

## Privacy Note
Recorded audio files (`.m4a`, `.aac`, `.wav`, `.mp3`, and `pending/` segments) are stored locally on the device and are never committed to version control.
