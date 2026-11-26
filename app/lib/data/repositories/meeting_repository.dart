import 'dart:io';

import '../../models/recording_item.dart';
import '../../services/recording_storage.dart';
import '../database/app_database.dart';
import '../demo/demo_meeting_seed.dart';

/// Coordinates Drift SQLite persistence with on-disk `.m4a` / `.peaks` files
/// and crash-recovery imports.
class MeetingRepository {
  MeetingRepository(this._db);

  final AppDatabase _db;

  /// Imports any un-indexed Phase 0 `.m4a` recordings from disk into Drift,
  /// and recovers orphaned pending sessions when no recording service is running.
  Future<List<RecordingItem>> syncFromDisk({
    required bool serviceIsRunning,
  }) async {
    var recovered = const <RecordingItem>[];
    if (!serviceIsRunning) {
      recovered = await RecordingStorage.recoverPendingSessions();
    }

    final diskItems = await RecordingStorage.listRecordings();
    for (final item in diskItems) {
      await _db.upsertMeetingFromRecording(item);
    }
    return recovered;
  }

  Future<void> saveRecordedMeeting(
    RecordingItem item, {
    String? glossary,
  }) async {
    await _db.upsertMeetingFromRecording(item, glossary: glossary);
  }

  Future<List<MeetingListItem>> listMeetings({String query = ''}) {
    return _db.listMeetings(query: query);
  }

  Future<MeetingDetailData?> getMeetingDetail(String id) {
    return _db.getMeetingDetail(id);
  }

  Future<void> renameMeeting(String id, String title) {
    return _db.updateMeetingTitle(id, title);
  }

  Future<void> updateGlossary(String id, String? glossary) {
    return _db.updateMeetingGlossary(id, glossary);
  }

  Future<void> updateLanguage(String id, String language) {
    return _db.updateMeetingLanguage(id, language);
  }

  Future<void> softDeleteMeeting(String id) {
    return _db.setMeetingSoftDeleted(id, true);
  }

  Future<void> restoreMeeting(String id) {
    return _db.setMeetingSoftDeleted(id, false);
  }

  Future<void> commitHardDelete(String id) async {
    final removed = await _db.hardDeleteMeeting(id);
    if (removed == null) return;
    await _deleteFilesForMeeting(removed);
  }

  Future<void> purgeSoftDeleted() async {
    final rows = await _db.purgeSoftDeletedMeetings();
    for (final row in rows) {
      await _deleteFilesForMeeting(row);
    }
  }

  Future<void> updateSegmentText(String segmentId, String text) {
    return _db.updateSegmentText(segmentId, text);
  }

  Future<void> toggleActionItem(String actionItemId, bool done) {
    return _db.toggleActionItem(actionItemId, done);
  }

  Future<void> addTag(String meetingId, String tagName) {
    return _db.addTagToMeeting(meetingId, tagName);
  }

  Future<void> removeTag(String meetingId, String tagId) {
    return _db.removeTagFromMeeting(meetingId, tagId);
  }

  Future<List<SearchHit>> search(String query) {
    return _db.searchMeetingsAndTranscripts(query);
  }

  Future<String> createDemoMeeting() {
    return DemoMeetingSeed.insertDemoMeeting(_db);
  }

  Future<void> deleteAllData() async {
    await _db.deleteAllData();
    await RecordingStorage.deleteAllRecordingFiles();
  }

  Future<void> _deleteFilesForMeeting(Meeting meeting) async {
    final audioPath = meeting.audioPath;
    if (audioPath != null && audioPath.isNotEmpty) {
      final f = File(audioPath);
      if (f.existsSync()) await f.delete();
      final jsonSidecar = File(
        '${audioPath.substring(0, audioPath.length - 4)}.json',
      );
      if (jsonSidecar.existsSync()) await jsonSidecar.delete();
    }
    final peaksPath = meeting.peaksPath;
    if (peaksPath != null && peaksPath.isNotEmpty) {
      final pFile = File(peaksPath);
      if (pFile.existsSync()) await pFile.delete();
    }
  }
}
