# Minute

Minute is an Android-first meeting and lecture recorder designed to capture reliable long-form audio—including mixed English/Malay (Manglish) speech—and produce timestamped, speaker-labeled transcripts, AI summaries, decisions, and action items.

## Tech Stack
- **Mobile (Android):** Flutter, Dart, Material 3, `record`, `flutter_foreground_task`, `just_audio`, `audio_session`, `permission_handler`, `device_info_plus`
- **Backend (upcoming):** Python FastAPI, SQLAlchemy, PostgreSQL, faster-whisper, pyannote.audio

## How to Run
```bash
cd app
flutter pub get
flutter run -d <device_id>
```

## Current Status
- **Phase 0: background recording spike complete** — foreground service (`microphone` type), 16 kHz mono AAC capture in continuous 30-second disk segments, native `.m4a` merging, interruption handling (Normal mode with post-call auto-resume + Force mode with silence markers), low-storage auto-stop, and local playback.

## Privacy Note
Recorded audio files (`.m4a`, `.aac`, `.wav`, `.mp3`, and `pending/` segments) are stored locally on the device and are never committed to version control.
