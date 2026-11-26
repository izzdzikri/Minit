import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../models/recording_item.dart';

part 'app_database.g.dart';

class Meetings extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get audioPath => text().nullable()();
  TextColumn get peaksPath => text().nullable()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  IntColumn get segmentCount => integer().withDefault(const Constant(1))();
  TextColumn get language => text().withDefault(const Constant('ms'))();
  TextColumn get status => text().withDefault(const Constant('Recorded'))();
  BoolColumn get isPartial => boolean().withDefault(const Constant(false))();
  BoolColumn get isForceMode => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get markersJson => text().withDefault(const Constant('[]'))();
  TextColumn get note => text().nullable()();
  TextColumn get serverMeetingId => text().nullable()();
  TextColumn get glossary => text().nullable()();
  TextColumn get statusMessage => text().nullable()();
  IntColumn get uploadProgress => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Speakers extends Table {
  TextColumn get id => text()();
  TextColumn get meetingId =>
      text().references(Meetings, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();
  TextColumn get displayName => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class TranscriptSegments extends Table {
  TextColumn get id => text()();
  TextColumn get meetingId =>
      text().references(Meetings, #id, onDelete: KeyAction.cascade)();
  TextColumn get speakerId => text()
      .nullable()
      .references(Speakers, #id, onDelete: KeyAction.setNull)();
  RealColumn get startSec => real()();
  RealColumn get endSec => real()();
  TextColumn get textContent => text()();
  BoolColumn get edited => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  RealColumn get avgLogprob => real().nullable()();
  RealColumn get noSpeechProb => real().nullable()();
  BoolColumn get isLoopFlagged =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Summaries extends Table {
  TextColumn get id => text()();
  TextColumn get meetingId =>
      text().references(Meetings, #id, onDelete: KeyAction.cascade)();
  TextColumn get summary => text()();
  TextColumn get keyPointsJson => text().withDefault(const Constant('[]'))();
  TextColumn get decisionsJson => text().withDefault(const Constant('[]'))();
  TextColumn get openQuestionsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get rawJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

class ActionItems extends Table {
  TextColumn get id => text()();
  TextColumn get meetingId =>
      text().references(Meetings, #id, onDelete: KeyAction.cascade)();
  TextColumn get task => text()();
  TextColumn get owner => text().withDefault(const Constant('Unassigned'))();
  TextColumn get dueDate => text().nullable()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();

  @override
  Set<Column> get primaryKey => {id};
}

class MeetingTags extends Table {
  TextColumn get meetingId =>
      text().references(Meetings, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {meetingId, tagId};
}

@DataClassName('UploadQueueEntry')
class UploadQueue extends Table {
  TextColumn get id => text()();
  TextColumn get meetingId => text()
      .unique()
      .references(Meetings, #id, onDelete: KeyAction.cascade)();
  TextColumn get filePath => text()();
  IntColumn get totalBytes => integer()();
  IntColumn get uploadedBytes => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get lastError => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class MeetingListItem {
  const MeetingListItem({
    required this.meeting,
    required this.tags,
    required this.summarySnippet,
    required this.markers,
    this.uploadEntry,
  });

  final Meeting meeting;
  final List<Tag> tags;
  final String? summarySnippet;
  final List<TimelineMarker> markers;
  final UploadQueueEntry? uploadEntry;
}

class TranscriptSegmentWithSpeaker {
  const TranscriptSegmentWithSpeaker({
    required this.segment,
    this.speaker,
  });

  final TranscriptSegment segment;
  final Speaker? speaker;
}

class ParsedSummary {
  const ParsedSummary({
    required this.row,
    required this.keyPoints,
    required this.decisions,
    required this.openQuestions,
  });

  final Summary row;
  final List<String> keyPoints;
  final List<String> decisions;
  final List<String> openQuestions;
}

class MeetingDetailData {
  const MeetingDetailData({
    required this.meeting,
    required this.speakers,
    required this.segments,
    required this.summary,
    required this.actionItems,
    required this.tags,
    required this.markers,
    this.uploadEntry,
  });

  final Meeting meeting;
  final List<Speaker> speakers;
  final List<TranscriptSegmentWithSpeaker> segments;
  final ParsedSummary? summary;
  final List<ActionItem> actionItems;
  final List<Tag> tags;
  final List<TimelineMarker> markers;
  final UploadQueueEntry? uploadEntry;
}

class SearchHit {
  const SearchHit({
    required this.meeting,
    required this.snippet,
    required this.matchedTitle,
    this.seekSec,
    this.speakerName,
  });

  final Meeting meeting;
  final String snippet;
  final bool matchedTitle;
  final double? seekSec;
  final String? speakerName;
}

class TranscriptSegmentDraft {
  const TranscriptSegmentDraft({
    required this.id,
    required this.speakerLabel,
    required this.startSec,
    required this.endSec,
    required this.textContent,
    this.avgLogprob,
    this.noSpeechProb,
    this.isLoopFlagged = false,
  });

  final String id;
  final String speakerLabel;
  final double startSec;
  final double endSec;
  final String textContent;
  final double? avgLogprob;
  final double? noSpeechProb;
  final bool isLoopFlagged;
}

@DriftDatabase(
  tables: [
    Meetings,
    Speakers,
    TranscriptSegments,
    Summaries,
    ActionItems,
    Tags,
    MeetingTags,
    UploadQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(meetings, meetings.serverMeetingId);
            await migrator.addColumn(meetings, meetings.glossary);
            await migrator.addColumn(meetings, meetings.statusMessage);
            await migrator.addColumn(meetings, meetings.uploadProgress);
            await migrator.addColumn(
              transcriptSegments,
              transcriptSegments.avgLogprob,
            );
            await migrator.addColumn(
              transcriptSegments,
              transcriptSegments.noSpeechProb,
            );
            await migrator.addColumn(
              transcriptSegments,
              transcriptSegments.isLoopFlagged,
            );
            await migrator.createTable(uploadQueue);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'minit_db');
  }

  static List<TimelineMarker> decodeMarkers(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => TimelineMarker.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  static List<String> _decodeStringList(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<List<MeetingListItem>> listMeetings({String query = ''}) async {
    final trimmed = query.trim().toLowerCase();
    final rows = await (select(meetings)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();

    final allTags = await select(tags).get();
    final tagById = {for (final t in allTags) t.id: t};
    final allMeetingTags = await select(meetingTags).get();
    final allSummaries = await select(summaries).get();
    final summaryByMeetingId = {
      for (final s in allSummaries) s.meetingId: s.summary,
    };
    final allUploads = await select(uploadQueue).get();
    final uploadByMeetingId = {
      for (final u in allUploads) u.meetingId: u,
    };

    final tagsByMeetingId = <String, List<Tag>>{};
    for (final link in allMeetingTags) {
      final tag = tagById[link.tagId];
      if (tag != null) {
        tagsByMeetingId.putIfAbsent(link.meetingId, () => []).add(tag);
      }
    }

    final result = <MeetingListItem>[];
    for (final m in rows) {
      final mTags = tagsByMeetingId[m.id] ?? const [];
      final snippet = summaryByMeetingId[m.id];
      if (trimmed.isNotEmpty) {
        final inTitle = m.title.toLowerCase().contains(trimmed);
        final inSummary = snippet?.toLowerCase().contains(trimmed) ?? false;
        final inTags = mTags.any((t) => t.name.toLowerCase().contains(trimmed));
        if (!inTitle && !inSummary && !inTags) continue;
      }
      result.add(
        MeetingListItem(
          meeting: m,
          tags: mTags,
          summarySnippet: snippet,
          markers: decodeMarkers(m.markersJson),
          uploadEntry: uploadByMeetingId[m.id],
        ),
      );
    }
    return result;
  }

  Future<MeetingDetailData?> getMeetingDetail(String id) async {
    final meeting = await (select(meetings)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (meeting == null) return null;

    final speakerRows = await (select(speakers)
          ..where((t) => t.meetingId.equals(id)))
        .get();
    final speakerMap = {for (final s in speakerRows) s.id: s};

    final segmentRows = await (select(transcriptSegments)
          ..where((t) => t.meetingId.equals(id))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.startSec),
          ]))
        .get();

    final summaryRow = await (select(summaries)
          ..where((t) => t.meetingId.equals(id)))
        .getSingleOrNull();

    final actionRows = await (select(actionItems)
          ..where((t) => t.meetingId.equals(id))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();

    final tagLinks = await (select(meetingTags)
          ..where((t) => t.meetingId.equals(id)))
        .get();
    final tagIds = tagLinks.map((e) => e.tagId).toList();
    final tagRows = tagIds.isEmpty
        ? const <Tag>[]
        : await (select(tags)..where((t) => t.id.isIn(tagIds))).get();

    final uploadRow = await (select(uploadQueue)
          ..where((t) => t.meetingId.equals(id)))
        .getSingleOrNull();

    return MeetingDetailData(
      meeting: meeting,
      speakers: speakerRows,
      segments: segmentRows
          .map(
            (s) => TranscriptSegmentWithSpeaker(
              segment: s,
              speaker: s.speakerId != null ? speakerMap[s.speakerId] : null,
            ),
          )
          .toList(),
      summary: summaryRow == null
          ? null
          : ParsedSummary(
              row: summaryRow,
              keyPoints: _decodeStringList(summaryRow.keyPointsJson),
              decisions: _decodeStringList(summaryRow.decisionsJson),
              openQuestions: _decodeStringList(summaryRow.openQuestionsJson),
            ),
      actionItems: actionRows,
      tags: tagRows,
      markers: decodeMarkers(meeting.markersJson),
      uploadEntry: uploadRow,
    );
  }

  Future<void> upsertMeetingFromRecording(
    RecordingItem item, {
    String? glossary,
  }) async {
    final existing = await (select(meetings)
          ..where((t) => t.id.equals(item.id)))
        .getSingleOrNull();
    final now = DateTime.now();
    await into(meetings).insertOnConflictUpdate(
      MeetingsCompanion(
        id: Value(item.id),
        title: Value(existing?.title ?? item.title),
        audioPath: Value(item.filePath),
        peaksPath: Value(item.peaksPath ?? existing?.peaksPath),
        durationMs: Value(item.durationMs),
        sizeBytes: Value(item.sizeBytes),
        segmentCount: Value(item.segmentCount),
        language: Value(item.language),
        status: Value(existing?.status ?? 'Recorded'),
        isPartial: Value(item.isPartial),
        isForceMode: Value(item.isForceMode),
        isDeleted: Value(existing?.isDeleted ?? false),
        markersJson: Value(
          jsonEncode(item.markers.map((m) => m.toJson()).toList()),
        ),
        note: Value(item.note ?? existing?.note),
        serverMeetingId: Value(existing?.serverMeetingId),
        glossary: Value(existing?.glossary ?? glossary),
        statusMessage: Value(existing?.statusMessage),
        uploadProgress: Value(existing?.uploadProgress ?? 0),
        createdAt: Value(item.createdAt),
        updatedAt: Value(now),
      ),
    );
  }

  Future<Meeting?> getMeetingById(String meetingId) {
    return (select(meetings)..where((t) => t.id.equals(meetingId)))
        .getSingleOrNull();
  }

  Future<void> updateMeetingTitle(String meetingId, String newTitle) async {
    await (update(meetings)..where((t) => t.id.equals(meetingId))).write(
      MeetingsCompanion(
        title: Value(newTitle.trim()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateMeetingGlossary(String meetingId, String? glossary) async {
    final trimmed = glossary?.trim();
    await (update(meetings)..where((t) => t.id.equals(meetingId))).write(
      MeetingsCompanion(
        glossary: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateMeetingLanguage(String meetingId, String language) async {
    await (update(meetings)..where((t) => t.id.equals(meetingId))).write(
      MeetingsCompanion(
        language: Value(language),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateMeetingServerState(
    String meetingId, {
    String? serverMeetingId,
    String? status,
    String? statusMessage,
    int? uploadProgress,
  }) async {
    await (update(meetings)..where((t) => t.id.equals(meetingId))).write(
      MeetingsCompanion(
        serverMeetingId: serverMeetingId != null
            ? Value(serverMeetingId)
            : const Value.absent(),
        status: status != null ? Value(status) : const Value.absent(),
        statusMessage: statusMessage != null
            ? Value(statusMessage)
            : const Value.absent(),
        uploadProgress: uploadProgress != null
            ? Value(uploadProgress)
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> upsertUploadQueueEntry({
    required String meetingId,
    required String filePath,
    required int totalBytes,
    int uploadedBytes = 0,
    String status = 'pending',
    String? lastError,
    int attempts = 0,
  }) async {
    final existing = await (select(uploadQueue)
          ..where((t) => t.meetingId.equals(meetingId)))
        .getSingleOrNull();
    final now = DateTime.now();
    await into(uploadQueue).insertOnConflictUpdate(
      UploadQueueCompanion(
        id: Value(existing?.id ?? 'uq_$meetingId'),
        meetingId: Value(meetingId),
        filePath: Value(filePath),
        totalBytes: Value(totalBytes),
        uploadedBytes: Value(uploadedBytes),
        status: Value(status),
        lastError: Value(lastError),
        attempts: Value(attempts),
        updatedAt: Value(now),
      ),
    );
  }

  Future<UploadQueueEntry?> getUploadEntryForMeeting(String meetingId) {
    return (select(uploadQueue)..where((t) => t.meetingId.equals(meetingId)))
        .getSingleOrNull();
  }

  Future<List<UploadQueueEntry>> listPendingUploads() {
    return (select(uploadQueue)
          ..where((t) => t.status.isIn(['pending', 'uploading', 'paused']))
          ..orderBy([(t) => OrderingTerm.asc(t.updatedAt)]))
        .get();
  }

  Future<List<Meeting>> listProcessingMeetings() {
    return (select(meetings)
          ..where(
            (t) =>
                t.isDeleted.equals(false) &
                t.status.isIn(['Queued', 'Transcribing']),
          ))
        .get();
  }

  Future<void> updateUploadProgress({
    required String meetingId,
    required int uploadedBytes,
    required int totalBytes,
    String? status,
    String? lastError,
    bool clearError = false,
    int? attempts,
  }) async {
    final existing = await getUploadEntryForMeeting(meetingId);
    if (existing == null) return;
    await (update(uploadQueue)..where((t) => t.meetingId.equals(meetingId)))
        .write(
      UploadQueueCompanion(
        uploadedBytes: Value(uploadedBytes),
        totalBytes: Value(totalBytes),
        status: status != null ? Value(status) : const Value.absent(),
        lastError: clearError
            ? const Value(null)
            : (lastError != null ? Value(lastError) : const Value.absent()),
        attempts: attempts != null ? Value(attempts) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> replaceMeetingTranscript({
    required String meetingId,
    required List<TranscriptSegmentDraft> segmentDrafts,
    String? detectedLanguage,
  }) async {
    await transaction(() async {
      await (delete(transcriptSegments)
            ..where((t) => t.meetingId.equals(meetingId)))
          .go();
      await (delete(speakers)..where((t) => t.meetingId.equals(meetingId)))
          .go();

      final speakerIdsByLabel = <String, String>{};
      for (final draft in segmentDrafts) {
        final label =
            draft.speakerLabel.trim().isEmpty ? 'Speaker 1' : draft.speakerLabel;
        if (!speakerIdsByLabel.containsKey(label)) {
          final spkId =
              'spk_${meetingId}_${speakerIdsByLabel.length + 1}';
          speakerIdsByLabel[label] = spkId;
          await into(speakers).insert(
            SpeakersCompanion.insert(
              id: spkId,
              meetingId: meetingId,
              label: label,
              displayName: label,
            ),
          );
        }
      }

      for (var i = 0; i < segmentDrafts.length; i++) {
        final draft = segmentDrafts[i];
        final label =
            draft.speakerLabel.trim().isEmpty ? 'Speaker 1' : draft.speakerLabel;
        await into(transcriptSegments).insert(
          TranscriptSegmentsCompanion.insert(
            id: draft.id,
            meetingId: meetingId,
            speakerId: Value(speakerIdsByLabel[label]),
            startSec: draft.startSec,
            endSec: draft.endSec,
            textContent: draft.textContent,
            edited: const Value(false),
            sortOrder: Value(i),
            avgLogprob: Value(draft.avgLogprob),
            noSpeechProb: Value(draft.noSpeechProb),
            isLoopFlagged: Value(draft.isLoopFlagged),
          ),
        );
      }

      await (update(meetings)..where((t) => t.id.equals(meetingId))).write(
        MeetingsCompanion(
          status: const Value('Ready'),
          statusMessage: const Value('Transcript ready.'),
          uploadProgress: const Value(100),
          language: detectedLanguage != null
              ? Value(detectedLanguage)
              : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> setMeetingSoftDeleted(String meetingId, bool deleted) async {
    await (update(meetings)..where((t) => t.id.equals(meetingId))).write(
      MeetingsCompanion(
        isDeleted: Value(deleted),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<Meeting?> hardDeleteMeeting(String meetingId) async {
    final row = await (select(meetings)..where((t) => t.id.equals(meetingId)))
        .getSingleOrNull();
    if (row == null) return null;
    await (delete(meetings)..where((t) => t.id.equals(meetingId))).go();
    return row;
  }

  Future<List<Meeting>> purgeSoftDeletedMeetings() async {
    final rows = await (select(meetings)
          ..where((t) => t.isDeleted.equals(true)))
        .get();
    if (rows.isNotEmpty) {
      await (delete(meetings)..where((t) => t.isDeleted.equals(true))).go();
    }
    return rows;
  }

  Future<void> updateSegmentText(String segmentId, String newText) async {
    await (update(transcriptSegments)..where((t) => t.id.equals(segmentId)))
        .write(
      TranscriptSegmentsCompanion(
        textContent: Value(newText),
        edited: const Value(true),
      ),
    );
  }

  Future<void> toggleActionItem(String actionItemId, bool done) async {
    await (update(actionItems)..where((t) => t.id.equals(actionItemId)))
        .write(ActionItemsCompanion(done: Value(done)));
  }

  Future<void> addTagToMeeting(String meetingId, String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return;

    final existingTag = await (select(tags)
          ..where((t) => t.name.lower().equals(name.toLowerCase())))
        .getSingleOrNull();
    final tagId =
        existingTag?.id ?? 'tag_${DateTime.now().microsecondsSinceEpoch}';
    if (existingTag == null) {
      await into(tags).insert(
        TagsCompanion.insert(id: tagId, name: name),
      );
    }

    await into(meetingTags).insert(
      MeetingTagsCompanion.insert(meetingId: meetingId, tagId: tagId),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> removeTagFromMeeting(String meetingId, String tagId) async {
    await (delete(meetingTags)
          ..where(
            (t) => t.meetingId.equals(meetingId) & t.tagId.equals(tagId),
          ))
        .go();
  }

  Future<List<SearchHit>> searchMeetingsAndTranscripts(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final activeMeetings = await (select(meetings)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    final meetingById = {for (final m in activeMeetings) m.id: m};
    if (meetingById.isEmpty) return const [];

    final hits = <SearchHit>[];
    final seenMeetingsFromSegments = <String>{};

    final allSpeakers = await select(speakers).get();
    final speakerMap = {for (final s in allSpeakers) s.id: s};

    final allSegments = await (select(transcriptSegments)
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.startSec),
          ]))
        .get();

    for (final seg in allSegments) {
      final meeting = meetingById[seg.meetingId];
      if (meeting == null) continue;
      if (seg.textContent.toLowerCase().contains(q)) {
        seenMeetingsFromSegments.add(meeting.id);
        final speaker =
            seg.speakerId != null ? speakerMap[seg.speakerId] : null;
        hits.add(
          SearchHit(
            meeting: meeting,
            snippet: seg.textContent,
            matchedTitle: false,
            seekSec: seg.startSec,
            speakerName: speaker?.displayName,
          ),
        );
      }
    }

    for (final m in activeMeetings) {
      if (m.title.toLowerCase().contains(q) &&
          !seenMeetingsFromSegments.contains(m.id)) {
        hits.add(
          SearchHit(
            meeting: m,
            snippet: m.title,
            matchedTitle: true,
          ),
        );
      }
    }

    return hits;
  }

  Future<void> insertFullMeetingGraph({
    required MeetingsCompanion meeting,
    required List<SpeakersCompanion> speakerRows,
    required List<TranscriptSegmentsCompanion> segmentRows,
    SummariesCompanion? summaryRow,
    required List<ActionItemsCompanion> actionItemRows,
    required List<String> tagNames,
  }) async {
    await transaction(() async {
      await into(meetings).insertOnConflictUpdate(meeting);
      for (final s in speakerRows) {
        await into(speakers).insertOnConflictUpdate(s);
      }
      for (final seg in segmentRows) {
        await into(transcriptSegments).insertOnConflictUpdate(seg);
      }
      if (summaryRow != null) {
        await into(summaries).insertOnConflictUpdate(summaryRow);
      }
      for (final act in actionItemRows) {
        await into(actionItems).insertOnConflictUpdate(act);
      }
      for (final tagName in tagNames) {
        await addTagToMeeting(meeting.id.value, tagName);
      }
    });
  }

  Future<void> deleteAllData() async {
    await transaction(() async {
      await delete(uploadQueue).go();
      await delete(meetingTags).go();
      await delete(tags).go();
      await delete(actionItems).go();
      await delete(summaries).go();
      await delete(transcriptSegments).go();
      await delete(speakers).go();
      await delete(meetings).go();
    });
  }
}
