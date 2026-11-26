import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../models/recording_item.dart';
import '../../services/peaks_storage.dart';
import '../../services/recording_storage.dart';
import '../database/app_database.dart';

/// Generates a realistic Malaysian team/lecture demo meeting (Manglish speech,
/// speakers, summary, decisions, action items, tags, timeline markers, and a
/// deterministic speech-envelope `.peaks` file) for Phase 1 dev testing.
class DemoMeetingSeed {
  DemoMeetingSeed._();

  static Future<String> insertDemoMeeting(AppDatabase db) async {
    final now = DateTime.now();
    final id = 'demo_${now.millisecondsSinceEpoch}';
    final recDir = await RecordingStorage.getRecordingsDirectory();
    final peaksPath = p.join(recDir.path, '$id.peaks');

    // 4 minutes (240s => 2,400 samples @ 100 ms) of speech-like envelope
    // including a quiet pause around 01:10-01:22 and clear speech bursts.
    const totalSamples = 2400;
    final levels = List<double>.generate(totalSamples, (i) {
      final sec = i / 10.0;
      if (sec >= 70 && sec <= 82) {
        return 0.0; // Simulated silence/gap
      }
      final phraseGate = math.sin(sec * 0.45) > -0.25 ? 1.0 : 0.08;
      final syllable =
          0.35 + 0.35 * math.sin(sec * 3.7).abs() + 0.25 * math.cos(sec * 7.1).abs();
      return (phraseGate * syllable).clamp(0.0, 0.96);
    }, growable: false);

    await PeaksStorage.writeNormalizedPeaks(
      levels: levels,
      outputPeaksPath: peaksPath,
    );

    final markers = [
      const TimelineMarker(
        type: MarkerType.marker,
        startMs: 32000,
        endMs: 32000,
        reason: 'Key deadline confirmed',
      ),
      const TimelineMarker(
        type: MarkerType.silence,
        startMs: 70000,
        endMs: 82000,
        reason: 'Mic silenced during check',
      ),
    ];

    final speakerA = '${id}_spk_1';
    final speakerB = '${id}_spk_2';
    final speakerC = '${id}_spk_3';

    final meetingRow = MeetingsCompanion(
      id: Value(id),
      title: const Value('Minit Sprint Sync & Manglish Audio Review'),
      audioPath: const Value(null),
      peaksPath: Value(peaksPath),
      durationMs: const Value(240000),
      sizeBytes: const Value(0),
      segmentCount: const Value(8),
      language: const Value('mixed'),
      status: const Value('Ready'),
      isPartial: const Value(false),
      isForceMode: const Value(false),
      isDeleted: const Value(false),
      markersJson: Value(jsonEncode(markers.map((m) => m.toJson()).toList())),
      note: const Value('Demo meeting with mixed English & Malay transcript.'),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    final speakerRows = [
      SpeakersCompanion(
        id: Value(speakerA),
        meetingId: Value(id),
        label: const Value('SPEAKER_00'),
        displayName: const Value('Aiman'),
      ),
      SpeakersCompanion(
        id: Value(speakerB),
        meetingId: Value(id),
        label: const Value('SPEAKER_01'),
        displayName: const Value('Mei Ling'),
      ),
      SpeakersCompanion(
        id: Value(speakerC),
        meetingId: Value(id),
        label: const Value('SPEAKER_02'),
        displayName: const Value('Farah'),
      ),
    ];

    final segmentsData = [
      (
        speakerId: speakerA,
        start: 0.0,
        end: 28.0,
        text:
            'Okay guys, kita mula terus. Today we need to lock down the Phase 1 recording UX and make sure waveform replay smooth even for a two-hour kuliah.',
      ),
      (
        speakerId: speakerB,
        start: 28.5,
        end: 68.0,
        text:
            'Agreed. Semalam I tested on iQOO, kalau guna 100 ms binary peaks file, dua jam baru around 72 KB — memang ringan and no decoding lag when scrubbing.',
      ),
      (
        speakerId: speakerC,
        start: 83.0,
        end: 132.0,
        text:
            'Nice! Tapi untuk Lecture mode nanti, students usually record mixed BM and English. Make sure "Copy for AI" prompt explicitly warns the model not to invent action items or due dates.',
      ),
      (
        speakerId: speakerA,
        start: 132.5,
        end: 185.0,
        text:
            'Betul tu. Let\'s confirm our decision: default audio interruption setting is keep recording when another app plays media, and auto-resume cleanly after a phone call.',
      ),
      (
        speakerId: speakerB,
        start: 185.5,
        end: 240.0,
        text:
            'Set! Farah, boleh tolong prepare the sample Manglish evaluation clips by Friday? I will verify the 200% font-scale layout and TalkBack labels before we move to Phase 2.',
      ),
    ];

    final segmentRows = [
      for (var i = 0; i < segmentsData.length; i++)
        TranscriptSegmentsCompanion(
          id: Value('${id}_seg_$i'),
          meetingId: Value(id),
          speakerId: Value(segmentsData[i].speakerId),
          startSec: Value(segmentsData[i].start),
          endSec: Value(segmentsData[i].end),
          textContent: Value(segmentsData[i].text),
          edited: const Value(false),
          sortOrder: Value(i),
        ),
    ];

    const keyPoints = [
      '100 ms quantized binary peaks file keeps a 2-hour recording waveform at ~72 KB with instant downsampling.',
      'Target users frequently speak mixed English and Bahasa Melayu (Manglish) during meetings and lectures.',
      'Normal mode defaults to keeping recording when media apps play audio while still auto-resuming around calls.',
    ];
    const decisions = [
      'Use 1-byte-per-100ms `.peaks` sidecars instead of decoding `.m4a` audio on the Meeting Detail screen.',
      'Default "When another app plays audio" to Keep recording.',
      'Include explicit anti-hallucination instructions in Copy for AI exports.',
    ];
    const openQuestions = [
      'Which faster-whisper model size gives the best BM/EN code-switching accuracy on the dev GPU?',
    ];

    final summaryRow = SummariesCompanion(
      id: Value('${id}_sum'),
      meetingId: Value(id),
      summary: const Value(
        'The team finalized the Phase 1 local waveform architecture and interruption defaults for mixed English/Malay recordings, ensuring fast replay scrubbing and accurate AI export formatting.',
      ),
      keyPointsJson: Value(jsonEncode(keyPoints)),
      decisionsJson: Value(jsonEncode(decisions)),
      openQuestionsJson: Value(jsonEncode(openQuestions)),
      rawJson: const Value('{}'),
    );

    final actionRows = [
      ActionItemsCompanion(
        id: Value('${id}_act_0'),
        meetingId: Value(id),
        task: const Value('Prepare sample Manglish lecture clips for Phase 2 STT benchmarking'),
        owner: const Value('Farah'),
        dueDate: const Value('Friday'),
        done: const Value(false),
        sortOrder: const Value(0),
      ),
      ActionItemsCompanion(
        id: Value('${id}_act_1'),
        meetingId: Value(id),
        task: const Value('Verify 200% font scale and TalkBack slider semantics on iQOO phone'),
        owner: const Value('Mei Ling'),
        dueDate: const Value('Tomorrow'),
        done: const Value(true),
        sortOrder: const Value(1),
      ),
      ActionItemsCompanion(
        id: Value('${id}_act_2'),
        meetingId: Value(id),
        task: const Value('Wire Copy for AI split-part exporter for >30k token transcripts'),
        owner: const Value('Aiman'),
        dueDate: const Value('Unclear'),
        done: const Value(false),
        sortOrder: const Value(2),
      ),
    ];

    await db.insertFullMeetingGraph(
      meeting: meetingRow,
      speakerRows: speakerRows,
      segmentRows: segmentRows,
      summaryRow: summaryRow,
      actionItemRows: actionRows,
      tagNames: const ['standup', 'manglish', 'phase-1'],
    );

    return id;
  }
}
