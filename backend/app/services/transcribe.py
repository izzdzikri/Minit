"""Transcription provider abstraction, chunking, loop protection, and faster-whisper."""

from __future__ import annotations

import logging
import re
import shutil
import subprocess
import tempfile
import threading
import wave
from abc import ABC, abstractmethod
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

from ..config import Settings

logger = logging.getLogger("minit.transcribe")

ProgressCallback = Callable[[int, str], None]

_WORD_RE = re.compile(r"[^\W_]+(?:'[^\W_]+)?", re.UNICODE)


@dataclass(frozen=True)
class TranscriptSegmentData:
    start_sec: float
    end_sec: float
    text: str
    speaker_label: str = "Speaker 1"
    avg_logprob: float | None = None
    no_speech_prob: float | None = None
    is_loop_flagged: bool = False


@dataclass(frozen=True)
class TranscriptionResult:
    duration_sec: float
    detected_language: str | None
    segments: list[TranscriptSegmentData] = field(default_factory=list)


@dataclass(frozen=True)
class AudioChunkPlan:
    start_sec: float
    end_sec: float
    keep_start_sec: float
    keep_end_sec: float
    cut_on_silence: bool


class TranscriptionProvider(ABC):
    """Pluggable speech-to-text adapter interface."""

    @abstractmethod
    def transcribe_audio(
        self,
        audio_path: Path,
        *,
        language_hint: str,
        glossary: str | None = None,
        silence_ranges: list[tuple[float, float]] | None = None,
        progress_cb: ProgressCallback | None = None,
    ) -> TranscriptionResult:
        """Transcribe audio file into timestamped segments."""


class CloudProvider(TranscriptionProvider):
    """Placeholder adapter for future cloud ASR providers (Phase 3/4)."""

    def transcribe_audio(
        self,
        audio_path: Path,
        *,
        language_hint: str,
        glossary: str | None = None,
        silence_ranges: list[tuple[float, float]] | None = None,
        progress_cb: ProgressCallback | None = None,
    ) -> TranscriptionResult:
        raise NotImplementedError("CloudProvider is not implemented in Phase 2.")


def format_glossary_prompt(glossary: str | None, max_chars: int = 320) -> str | None:
    """Compact user glossary terms cleanly within Whisper's 224-token prompt window."""
    if not glossary:
        return None
    cleaned = ", ".join(part.strip() for part in re.split(r"[,;\n]+", glossary) if part.strip())
    if not cleaned:
        return None
    prefix = "Technical terms: "
    budget = max_chars - len(prefix)
    if len(cleaned) <= budget:
        return f"{prefix}{cleaned}."
    truncated = cleaned[:budget].rsplit(",", 1)[0].strip()
    return f"{prefix}{truncated or cleaned[:budget].strip()}."


def detect_repetition_loop(text: str, max_consecutive_repeats: int = 4) -> str | None:
    """Return the repeated word or short phrase if it occurs > `max_consecutive_repeats` times in a row."""
    words = _WORD_RE.findall(text.lower())
    if len(words) <= max_consecutive_repeats:
        return None

    limit = max_consecutive_repeats + 1  # "> 4 times in a row" means 5+
    max_ngram = min(6, len(words) // limit)
    for n in range(1, max_ngram + 1):
        i = 0
        while i + n * limit <= len(words):
            gram = tuple(words[i : i + n])
            count = 1
            j = i + n
            while j + n <= len(words) and tuple(words[j : j + n]) == gram:
                count += 1
                j += n
            if count >= limit:
                return " ".join(gram)
            i += 1
    return None


def normalize_audio_to_wav(input_path: Path, output_wav: Path) -> float:
    """Convert any supported audio file to 16 kHz mono 16-bit PCM WAV via ffmpeg."""
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("ffmpeg binary is not installed or not on PATH.")
    cmd = [
        ffmpeg,
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        str(input_path),
        "-ar",
        "16000",
        "-ac",
        "1",
        "-c:a",
        "pcm_s16le",
        str(output_wav),
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"ffmpeg normalization failed: {res.stderr.strip()[:200]}")

    with wave.open(str(output_wav), "rb") as wf:
        frames = wf.getnframes()
        rate = wf.getframerate()
        return frames / float(rate) if rate > 0 else 0.0


def extract_wav_slice(
    src_wav: Path,
    dst_wav: Path,
    start_sec: float,
    end_sec: float,
) -> float:
    """Copy a sample-aligned `[start_sec, end_sec]` window from a 16 kHz mono PCM WAV."""
    with wave.open(str(src_wav), "rb") as src:
        sr = src.getframerate()
        nch = src.getnchannels()
        sw = src.getsampwidth()
        total = src.getnframes()
        s_frame = max(0, min(total, int(round(start_sec * sr))))
        e_frame = max(s_frame, min(total, int(round(end_sec * sr))))
        src.setpos(s_frame)
        raw = src.readframes(e_frame - s_frame)

    with wave.open(str(dst_wav), "wb") as dst:
        dst.setnchannels(nch)
        dst.setsampwidth(sw)
        dst.setframerate(sr)
        dst.writeframes(raw)
    return (e_frame - s_frame) / float(sr) if sr > 0 else 0.0


def plan_audio_chunks(
    wav_path: Path,
    total_duration_sec: float,
    chunk_duration_sec: float,
    overlap_sec: float,
    silence_search_window_sec: float = 15.0,
    silence_rms_threshold: float = 0.015,
) -> list[AudioChunkPlan]:
    """Partition long recordings cleanly: cut at nearby silence gaps, or overlap + midpoint trim."""
    if total_duration_sec <= chunk_duration_sec or chunk_duration_sec <= 0:
        return [
            AudioChunkPlan(
                start_sec=0.0,
                end_sec=total_duration_sec,
                keep_start_sec=0.0,
                keep_end_sec=total_duration_sec,
                cut_on_silence=True,
            )
        ]

    with wave.open(str(wav_path), "rb") as wf:
        sr = wf.getframerate()
        n_frames = wf.getnframes()
        raw = wf.readframes(n_frames)
    samples = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0

    chunks: list[AudioChunkPlan] = []
    decode_start = 0.0
    keep_start = 0.0

    while decode_start < total_duration_sec:
        target_end = decode_start + chunk_duration_sec
        if target_end >= total_duration_sec - silence_search_window_sec:
            chunks.append(
                AudioChunkPlan(
                    start_sec=round(decode_start, 3),
                    end_sec=round(total_duration_sec, 3),
                    keep_start_sec=round(keep_start, 3),
                    keep_end_sec=round(total_duration_sec, 3),
                    cut_on_silence=True,
                )
            )
            break

        # Search +-15s around target boundary for the quietest 250ms silence window.
        win_start = max(decode_start + 10.0, target_end - silence_search_window_sec)
        win_end = min(total_duration_sec - 1.0, target_end + silence_search_window_sec)
        frame_len = max(1, int(0.25 * sr))
        step_len = max(1, int(0.05 * sr))

        best_rms = float("inf")
        best_mid_sec = target_end
        s_idx = int(win_start * sr)
        e_idx = int(win_end * sr)
        for idx in range(s_idx, max(s_idx + 1, e_idx - frame_len), step_len):
            rms = float(np.sqrt(np.mean(samples[idx : idx + frame_len] ** 2)))
            if rms < best_rms:
                best_rms = rms
                best_mid_sec = (idx + frame_len * 0.5) / float(sr)

        if best_rms <= silence_rms_threshold:
            cut_sec = round(best_mid_sec, 3)
            chunks.append(
                AudioChunkPlan(
                    start_sec=round(decode_start, 3),
                    end_sec=cut_sec,
                    keep_start_sec=round(keep_start, 3),
                    keep_end_sec=cut_sec,
                    cut_on_silence=True,
                )
            )
            decode_start = cut_sec
            keep_start = cut_sec
        else:
            half_ov = overlap_sec * 0.5
            mid_sec = round(target_end, 3)
            decode_end = min(total_duration_sec, round(mid_sec + half_ov, 3))
            chunks.append(
                AudioChunkPlan(
                    start_sec=round(decode_start, 3),
                    end_sec=decode_end,
                    keep_start_sec=round(keep_start, 3),
                    keep_end_sec=mid_sec,
                    cut_on_silence=False,
                )
            )
            decode_start = max(0.0, round(mid_sec - half_ov, 3))
            keep_start = mid_sec

    return chunks


def _deduplicate_seam(existing: list[TranscriptSegmentData], candidate: TranscriptSegmentData) -> str:
    """Trim accidental 1-3 word overlap if an overlap-split segment crosses a chunk boundary."""
    if not existing:
        return candidate.text.strip()
    prev = existing[-1]
    if candidate.start_sec - prev.end_sec > 2.5:
        return candidate.text.strip()
    prev_words = prev.text.strip().split()
    curr_words = candidate.text.strip().split()
    max_overlap = min(6, len(prev_words), len(curr_words))
    for k in range(max_overlap, 0, -1):
        if [w.lower().strip(".,!?") for w in prev_words[-k:]] == [
            w.lower().strip(".,!?") for w in curr_words[:k]
        ]:
            return " ".join(curr_words[k:]).strip()
    return candidate.text.strip()


class FasterWhisperProvider(TranscriptionProvider):
    """Local faster-whisper transcription engine with VAD, loop guard, and glossary support."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._model_lock = threading.Lock()
        self._model = None

    def _get_model(self):
        with self._model_lock:
            if self._model is None:
                import ctranslate2
                from faster_whisper import WhisperModel

                has_cuda = False
                try:
                    has_cuda = int(ctranslate2.get_cuda_device_count()) > 0
                except Exception:
                    has_cuda = False
                device = "cuda" if has_cuda else "cpu"
                compute_type = (
                    "float16"
                    if has_cuda and self._settings.WHISPER_COMPUTE_TYPE == "int8"
                    else self._settings.WHISPER_COMPUTE_TYPE
                )
                logger.info(
                    "Loading WhisperModel size=%s device=%s compute_type=%s",
                    self._settings.WHISPER_MODEL_SIZE,
                    device,
                    compute_type,
                )
                self._model = WhisperModel(
                    self._settings.WHISPER_MODEL_SIZE,
                    device=device,
                    compute_type=compute_type,
                    cpu_threads=self._settings.WHISPER_CPU_THREADS,
                )
            return self._model

    @staticmethod
    def _resolve_language_arg(language_hint: str) -> str | None:
        norm = language_hint.strip().lower()
        if norm in {"auto", ""}:
            return None
        if norm == "mixed":
            return "ms"
        return norm

    def _transcribe_slice_once(
        self,
        model,
        wav_path: Path,
        *,
        language_arg: str | None,
        initial_prompt: str | None,
    ):
        return model.transcribe(
            str(wav_path),
            language=language_arg,
            vad_filter=self._settings.WHISPER_VAD_FILTER,
            condition_on_previous_text=self._settings.WHISPER_CONDITION_ON_PREVIOUS_TEXT,
            compression_ratio_threshold=self._settings.WHISPER_COMPRESSION_RATIO_THRESHOLD,
            no_speech_threshold=self._settings.WHISPER_NO_SPEECH_THRESHOLD,
            log_prob_threshold=self._settings.WHISPER_LOG_PROB_THRESHOLD,
            temperature=self._settings.temperatures_list,
            initial_prompt=initial_prompt,
        )

    def _retry_loop_segment(
        self,
        model,
        chunk_wav: Path,
        tmp_dir: Path,
        chunk_start_sec: float,
        seg_start: float,
        seg_end: float,
        language_arg: str | None,
    ) -> list[TranscriptSegmentData] | None:
        pad_start = max(0.0, seg_start - 0.25)
        pad_end = max(pad_start + 0.5, seg_end + 0.25)
        retry_wav = tmp_dir / "loop_retry.wav"
        sliced_dur = extract_wav_slice(chunk_wav, retry_wav, pad_start, pad_end)
        if sliced_dur <= 0.1:
            return None

        segs_iter, _ = model.transcribe(
            str(retry_wav),
            language=language_arg,
            vad_filter=False,
            condition_on_previous_text=False,
            compression_ratio_threshold=2.0,
            no_speech_threshold=self._settings.WHISPER_NO_SPEECH_THRESHOLD,
            log_prob_threshold=self._settings.WHISPER_LOG_PROB_THRESHOLD,
            temperature=[0.2, 0.4, 0.6],
            repetition_penalty=1.2,
            no_repeat_ngram_size=3,
            initial_prompt=None,
        )
        retried: list[TranscriptSegmentData] = []
        for rseg in segs_iter:
            txt = rseg.text.strip()
            if not txt:
                continue
            still_loops = (
                detect_repetition_loop(txt, self._settings.LOOP_REPEAT_THRESHOLD)
                is not None
            )
            retried.append(
                TranscriptSegmentData(
                    start_sec=round(chunk_start_sec + pad_start + float(rseg.start), 2),
                    end_sec=round(chunk_start_sec + pad_start + float(rseg.end), 2),
                    text=txt,
                    speaker_label="Speaker 1",
                    avg_logprob=round(float(rseg.avg_logprob), 4),
                    no_speech_prob=round(float(rseg.no_speech_prob), 4),
                    is_loop_flagged=still_loops,
                )
            )
        return retried or None

    def transcribe_audio(
        self,
        audio_path: Path,
        *,
        language_hint: str,
        glossary: str | None = None,
        silence_ranges: list[tuple[float, float]] | None = None,
        progress_cb: ProgressCallback | None = None,
    ) -> TranscriptionResult:
        tmp_base = self._settings.storage_path / "tmp"
        tmp_base.mkdir(parents=True, exist_ok=True)
        language_arg = self._resolve_language_arg(language_hint)
        prompt = format_glossary_prompt(glossary)
        silence_count = len(silence_ranges or [])

        with tempfile.TemporaryDirectory(prefix="minit_tx_", dir=str(tmp_base)) as td:
            tmp_dir = Path(td)
            normalized_wav = tmp_dir / "normalized_16k_mono.wav"
            if progress_cb:
                progress_cb(12, "Normalizing audio to 16 kHz mono...")
            duration_sec = normalize_audio_to_wav(audio_path, normalized_wav)
            if duration_sec <= 0.0:
                raise RuntimeError("Audio file has zero duration.")

            chunks = plan_audio_chunks(
                normalized_wav,
                duration_sec,
                chunk_duration_sec=float(self._settings.WHISPER_CHUNK_DURATION_SEC),
                overlap_sec=float(self._settings.WHISPER_CHUNK_OVERLAP_SEC),
            )
            logger.info(
                "Prepared %d audio chunk(s), duration=%.1fs, silence_hints=%d",
                len(chunks),
                duration_sec,
                silence_count,
            )

            model = self._get_model()
            all_segments: list[TranscriptSegmentData] = []
            detected_language: str | None = language_arg

            for idx, chunk in enumerate(chunks):
                if progress_cb:
                    pct = 18 + int((idx / max(1, len(chunks))) * 70)
                    progress_cb(
                        pct,
                        f"Transcribing part {idx + 1} of {len(chunks)}...",
                    )
                chunk_wav = (
                    normalized_wav
                    if len(chunks) == 1
                    else tmp_dir / f"chunk_{idx}.wav"
                )
                if len(chunks) > 1:
                    extract_wav_slice(
                        normalized_wav, chunk_wav, chunk.start_sec, chunk.end_sec
                    )

                segs_iter, info = self._transcribe_slice_once(
                    model,
                    chunk_wav,
                    language_arg=language_arg,
                    initial_prompt=prompt,
                )
                if detected_language is None and info and info.language:
                    detected_language = info.language

                for seg in segs_iter:
                    txt = seg.text.strip()
                    if not txt:
                        continue
                    abs_start = round(chunk.start_sec + float(seg.start), 2)
                    abs_end = round(chunk.start_sec + float(seg.end), 2)
                    midpoint = (abs_start + abs_end) * 0.5
                    if len(chunks) > 1 and (
                        midpoint < chunk.keep_start_sec or midpoint > chunk.keep_end_sec
                    ):
                        continue

                    repeated = detect_repetition_loop(
                        txt, self._settings.LOOP_REPEAT_THRESHOLD
                    )
                    if repeated is not None:
                        logger.info(
                            "Loop detected in chunk=%d window [%.2f, %.2f]; retrying once.",
                            idx,
                            abs_start,
                            abs_end,
                        )
                        retried = self._retry_loop_segment(
                            model,
                            chunk_wav,
                            tmp_dir,
                            chunk.start_sec,
                            float(seg.start),
                            float(seg.end),
                            language_arg,
                        )
                        if retried:
                            for r_item in retried:
                                r_mid = (r_item.start_sec + r_item.end_sec) * 0.5
                                if len(chunks) > 1 and (
                                    r_mid < chunk.keep_start_sec
                                    or r_mid > chunk.keep_end_sec
                                ):
                                    continue
                                clean_text = (
                                    _deduplicate_seam(all_segments, r_item)
                                    if not chunk.cut_on_silence
                                    else r_item.text
                                )
                                if clean_text:
                                    all_segments.append(
                                        TranscriptSegmentData(
                                            start_sec=r_item.start_sec,
                                            end_sec=r_item.end_sec,
                                            text=clean_text,
                                            speaker_label=r_item.speaker_label,
                                            avg_logprob=r_item.avg_logprob,
                                            no_speech_prob=r_item.no_speech_prob,
                                            is_loop_flagged=r_item.is_loop_flagged,
                                        )
                                    )
                            continue

                        # Retry produced nothing -> preserve original uncertain text and flag it.
                        item = TranscriptSegmentData(
                            start_sec=abs_start,
                            end_sec=abs_end,
                            text=txt,
                            speaker_label="Speaker 1",
                            avg_logprob=round(float(seg.avg_logprob), 4),
                            no_speech_prob=round(float(seg.no_speech_prob), 4),
                            is_loop_flagged=True,
                        )
                    else:
                        item = TranscriptSegmentData(
                            start_sec=abs_start,
                            end_sec=abs_end,
                            text=txt,
                            speaker_label="Speaker 1",
                            avg_logprob=round(float(seg.avg_logprob), 4),
                            no_speech_prob=round(float(seg.no_speech_prob), 4),
                            is_loop_flagged=False,
                        )

                    clean_text = (
                        _deduplicate_seam(all_segments, item)
                        if not chunk.cut_on_silence
                        else item.text
                    )
                    if clean_text:
                        all_segments.append(
                            TranscriptSegmentData(
                                start_sec=item.start_sec,
                                end_sec=item.end_sec,
                                text=clean_text,
                                speaker_label=item.speaker_label,
                                avg_logprob=item.avg_logprob,
                                no_speech_prob=item.no_speech_prob,
                                is_loop_flagged=item.is_loop_flagged,
                            )
                        )

            if progress_cb:
                progress_cb(94, "Saving transcript segments...")

            return TranscriptionResult(
                duration_sec=round(duration_sec, 2),
                detected_language=detected_language,
                segments=all_segments,
            )


def build_transcription_provider(settings: Settings) -> TranscriptionProvider:
    if settings.TRANSCRIPTION_PROVIDER == "cloud":
        return CloudProvider()
    return FasterWhisperProvider(settings)
