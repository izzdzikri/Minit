import 'package:flutter_test/flutter_test.dart';
import 'package:minit/data/database/app_database.dart';
import 'package:minit/models/recording_item.dart';
import 'package:minit/services/markdown_exporter.dart';

MeetingDetailData _buildSampleDetail({
  String title = 'Sprint "Sync": Q4 Planning',
  bool includeSummary = true,
  int extraSegmentCount = 0,
}) {
  final created = DateTime(2026, 11, 26, 10, 15);
  final meeting = Meeting(
    id: 'm1',
    title: title,
    audioPath: '/tmp/m1.m4a',
    peaksPath: '/tmp/m1.peaks',
    durationMs: 3600000,
    sizeBytes: 1200000,
    segmentCount: 10,
    language: 'mixed',
    status: 'Ready',
    isPartial: false,
    isForceMode: false,
    isDeleted: false,
    markersJson: '[]',
    note: null,
    uploadProgress: 0,
    createdAt: created,
    updatedAt: created,
  );

  final speakers = [
    const Speaker(
      id: 's1',
      meetingId: 'm1',
      label: 'A',
      displayName: 'Aiman "Lead"',
    ),
    const Speaker(
      id: 's2',
      meetingId: 'm1',
      label: 'N',
      displayName: 'Nurul: Design',
    ),
  ];

  final segments = <TranscriptSegmentWithSpeaker>[
    TranscriptSegmentWithSpeaker(
      speaker: speakers[0],
      segment: const TranscriptSegment(
        id: 'seg1',
        meetingId: 'm1',
        speakerId: 's1',
        startSec: 12.0,
        endSec: 25.0,
        textContent: 'Morning team, kita start dengan review bajet hari ini.',
        edited: false,
        sortOrder: 0,
        isLoopFlagged: false,
      ),
    ),
    TranscriptSegmentWithSpeaker(
      speaker: speakers[1],
      segment: const TranscriptSegment(
        id: 'seg2',
        meetingId: 'm1',
        speakerId: 's2',
        startSec: 900.0,
        endSec: 920.0,
        textContent: 'Okay, mockup sudah siap for user testing #sprint-1.',
        edited: true,
        sortOrder: 1,
        isLoopFlagged: false,
      ),
    ),
  ];

  for (var i = 0; i < extraSegmentCount; i++) {
    segments.add(
      TranscriptSegmentWithSpeaker(
        speaker: speakers[i % 2],
        segment: TranscriptSegment(
          id: 'extra_$i',
          meetingId: 'm1',
          speakerId: speakers[i % 2].id,
          startSec: 930.0 + (i * 5),
          endSec: 934.0 + (i * 5),
          textContent:
              'Line $i: Kita bincang detailed implementation notes, edge cases, '
              'architecture trade-offs, performance targets, and testing milestones.',
          edited: false,
          sortOrder: i + 2,
          isLoopFlagged: false,
        ),
      ),
    );
  }

  final summary = includeSummary
      ? ParsedSummary(
          row: const Summary(
            id: 'sum1',
            meetingId: 'm1',
            summary: 'Team aligned on Q4 budget and usability testing dates.',
            keyPointsJson: '[]',
            decisionsJson: '[]',
            openQuestionsJson: '[]',
            rawJson: '{}',
          ),
          keyPoints: const ['Reviewed Q4 budget', 'UI mockups finalized'],
          decisions: const ['Proceed with local-first architecture'],
          openQuestions: const ['Need confirmation on test lab slot'],
        )
      : null;

  final actions = includeSummary
      ? [
          const ActionItem(
            id: 'a1',
            meetingId: 'm1',
            task: 'Send final PDF',
            owner: 'Aiman',
            dueDate: 'Friday',
            done: false,
            sortOrder: 0,
          ),
        ]
      : const <ActionItem>[];

  const markers = [
    TimelineMarker(
      type: MarkerType.marker,
      startMs: 860000, // 00:14:20
      reason: 'budget question',
    ),
    TimelineMarker(
      type: MarkerType.callGap,
      startMs: 910000,
      reason: 'Incoming phone call',
      gapDurationMs: 45000,
    ),
  ];

  return MeetingDetailData(
    meeting: meeting,
    speakers: speakers,
    segments: segments,
    summary: summary,
    actionItems: actions,
    tags: const [Tag(id: 't1', name: 'sprint')],
    markers: markers,
  );
}

void main() {
  group('MarkdownExporter', () {
    test('exports transcriptOnly mode with chronological markers and YAML escaping',
        () {
      final detail = _buildSampleDetail();
      final md = MarkdownExporter.generate(detail, ExportMode.transcriptOnly);

      expect(md, contains('---'));
      expect(md, contains(r'title: "Sprint \"Sync\": Q4 Planning"'));
      expect(md, contains('duration: "01:00:00"'));
      expect(md, contains('# Transcript'));
      expect(md, isNot(contains('# Summary')));
      expect(md, isNot(contains('# Instructions for the AI')));

      expect(md, contains('**[00:00:12] Aiman "Lead":** Morning team'));
      expect(md, contains('[00:14:20] (marker: budget question)'));
      expect(md, contains('[00:15:10] (marker: call interruption 00:45)'));

      // Check chronological ordering
      final idxSeg1 = md.indexOf('[00:00:12]');
      final idxMarker = md.indexOf('[00:14:20]');
      final idxSeg2 = md.indexOf('[00:15:00]');
      final idxCall = md.indexOf('[00:15:10]');
      expect(idxSeg1 < idxMarker, isTrue);
      expect(idxMarker < idxSeg2, isTrue);
      expect(idxSeg2 < idxCall, isTrue);
    });

    test('exports summaryOnly mode and handles null summary cleanly', () {
      final withSummary = MarkdownExporter.generate(
        _buildSampleDetail(includeSummary: true),
        ExportMode.summaryOnly,
      );
      expect(withSummary, contains('# Summary'));
      expect(withSummary, contains('## Action items'));
      expect(withSummary, contains('- [ ] Send final PDF — **Aiman** (due: Friday)'));
      expect(withSummary, isNot(contains('# Transcript')));

      final withoutSummary = MarkdownExporter.generate(
        _buildSampleDetail(includeSummary: false),
        ExportMode.summaryOnly,
      );
      expect(withoutSummary, contains('_No summary available yet._'));
    });

    test('exports fullWithAiPrompt mode cleanly', () {
      final detail = _buildSampleDetail();
      final md = MarkdownExporter.generate(detail, ExportMode.fullWithAiPrompt);
      expect(md, contains('# Instructions for the AI'));
      expect(md, contains('# Summary'));
      expect(md, contains('# Transcript'));
    });

    test('splits outputs over 30,000 tokens into Part X of Y headers', () {
      final largeDetail = _buildSampleDetail(extraSegmentCount: 1100);
      final md = MarkdownExporter.generate(
        largeDetail,
        ExportMode.transcriptOnly,
      );

      final tokens = MarkdownExporter.estimateTokens(md);
      expect(tokens, greaterThan(30000));
      expect(MarkdownExporter.needsSplitting(md), isTrue);

      final parts = MarkdownExporter.splitIntoParts(md);
      expect(parts.length, greaterThan(1));
      for (var i = 0; i < parts.length; i++) {
        expect(parts[i], startsWith('Part ${i + 1} of ${parts.length}\n\n'));
        expect(
          MarkdownExporter.estimateTokens(parts[i]),
          lessThanOrEqualTo(30000),
        );
      }
    });
  });
}
