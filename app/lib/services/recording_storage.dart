import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/recording_item.dart';
import 'app_settings.dart';
import 'native_bridge.dart';
import 'peaks_storage.dart';

/// Manages local `.m4a` recordings, `.peaks` waveform files, metadata sidecars,
/// and crash recovery of unmerged 30-second `.aac` segment directories.
class RecordingStorage {
  RecordingStorage._();

  @visibleForTesting
  static Directory? testBaseDirectory;

  static Future<Directory> getRecordingsDirectory() async {
    final docs = testBaseDirectory ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'recordings'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  static Future<Directory> getPendingRootDirectory() async {
    final recordingsDir = await getRecordingsDirectory();
    final dir = Directory(p.join(recordingsDir.path, 'pending'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  static Future<bool> getForceMode() async {
    final settings = await AppSettingsStorage.load();
    return settings.forceRecordMode;
  }

  static Future<void> setForceMode(bool enabled) async {
    final current = await AppSettingsStorage.load();
    await AppSettingsStorage.save(current.copyWith(forceRecordMode: enabled));
  }

  static Future<void> saveMetadata(RecordingItem item) async {
    final jsonPath = _metadataPathForAudio(item.filePath);
    final tmpFile = File('$jsonPath.tmp');
    tmpFile.writeAsStringSync(item.toJsonString(), flush: true);
    tmpFile.renameSync(jsonPath);
  }

  static Future<List<RecordingItem>> listRecordings() async {
    final dir = await getRecordingsDirectory();
    final entities = dir.listSync();
    final items = <RecordingItem>[];
    final seenAudioPaths = <String>{};

    for (final entity in entities) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final raw = entity.readAsStringSync();
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) continue;
        final item = RecordingItem.fromJson(decoded);
        final audioFile = File(item.filePath);
        if (audioFile.existsSync() && audioFile.lengthSync() > 0) {
          items.add(item);
          seenAudioPaths.add(item.filePath);
        }
      } catch (_) {
        // Ignore malformed sidecar files; orphaned .m4a fallback picks up valid audio.
      }
    }

    for (final entity in entities) {
      if (entity is! File || !entity.path.endsWith('.m4a')) continue;
      if (seenAudioPaths.contains(entity.path)) continue;
      final stat = entity.statSync();
      if (stat.size <= 0) continue;
      final name = p.basenameWithoutExtension(entity.path);
      final candidatePeaks = File(p.join(dir.path, '$name.peaks'));
      items.add(
        RecordingItem(
          id: name,
          title: name,
          filePath: entity.path,
          peaksPath:
              candidatePeaks.existsSync() ? candidatePeaks.path : null,
          createdAt: stat.modified,
          durationMs: 0,
          sizeBytes: stat.size,
          segmentCount: 1,
        ),
      );
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  /// Recovers any unmerged session directories left behind by a crash or OS kill,
  /// rebuilding both the merged `.m4a` file and its full `.peaks` waveform file.
  /// Only call this when the background recording service is NOT running.
  static Future<List<RecordingItem>> recoverPendingSessions({
    Future<MergeResult> Function({
      required List<String> segmentPaths,
      required String outputPath,
    })? mergeAudioOverride,
  }) async {
    final pendingRoot = await getPendingRootDirectory();
    final recordingsDir = await getRecordingsDirectory();
    final recovered = <RecordingItem>[];

    final entries = pendingRoot.listSync();
    for (final entry in entries) {
      if (entry is! Directory) continue;

      final sessionId = p.basename(entry.path);
      final metaFile = File(p.join(entry.path, 'session.json'));
      PendingSessionMetadata? meta;
      if (metaFile.existsSync()) {
        try {
          final decoded = jsonDecode(metaFile.readAsStringSync());
          if (decoded is Map<String, dynamic>) {
            meta = PendingSessionMetadata.fromJson(decoded);
          }
        } catch (_) {}
      }

      final allFiles = entry.listSync().whereType<File>().toList();
      final segmentFiles = allFiles
          .where((f) => f.path.endsWith('.aac') && f.lengthSync() > 7)
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      if (segmentFiles.isEmpty) {
        await entry.delete(recursive: true);
        continue;
      }

      final peaksFiles = allFiles
          .where((f) => f.path.endsWith('.peaks') && f.lengthSync() > 0)
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      final outputPath =
          p.join(recordingsDir.path, '${sessionId}_recovered.m4a');
      final outputPeaksPath =
          p.join(recordingsDir.path, '${sessionId}_recovered.peaks');

      try {
        final merger = mergeAudioOverride ?? NativeBridge.mergeAacSegmentsToM4a;
        final merged = await merger(
          segmentPaths: segmentFiles.map((f) => f.path).toList(),
          outputPath: outputPath,
        );
        final mergedPeaksPath = await PeaksStorage.mergeSegmentPeaks(
          segmentPeaksPaths: peaksFiles.map((f) => f.path).toList(),
          outputPeaksPath: outputPeaksPath,
        );

        final item = RecordingItem(
          id: '${sessionId}_recovered',
          title: '${meta?.title ?? 'Recording'} (Recovered partial)',
          filePath: merged.outputPath,
          peaksPath: mergedPeaksPath,
          createdAt: meta?.createdAt ?? DateTime.now(),
          durationMs: merged.durationMs,
          sizeBytes: merged.sizeBytes,
          segmentCount: merged.segmentsMerged,
          language: meta?.language ?? 'auto',
          isPartial: true,
          isForceMode: meta?.isForceMode ?? false,
          markers: meta?.markers ?? const [],
          note: meta?.note ?? 'Recovered segments after an unexpected stop.',
        );
        await saveMetadata(item);
        await entry.delete(recursive: true);
        recovered.add(item);
      } catch (_) {
        // Leave pending segments untouched if recovery failed so audio isn't deleted.
      }
    }

    return recovered;
  }

  static Future<void> deleteRecording(RecordingItem item) async {
    final audioFile = File(item.filePath);
    if (audioFile.existsSync()) {
      await audioFile.delete();
    }
    if (item.peaksPath != null) {
      final peaksFile = File(item.peaksPath!);
      if (peaksFile.existsSync()) {
        await peaksFile.delete();
      }
    }
    final metaFile = File(_metadataPathForAudio(item.filePath));
    if (metaFile.existsSync()) {
      await metaFile.delete();
    }
  }

  /// Calculates total bytes used on disk by local recordings, peaks, and DB files.
  static Future<int> getTotalStorageBytes() async {
    final recordingsDir = await getRecordingsDirectory();
    final docsDir = recordingsDir.parent;
    var total = 0;

    if (recordingsDir.existsSync()) {
      for (final entity in recordingsDir.listSync(recursive: true)) {
        if (entity is File) {
          total += entity.lengthSync();
        }
      }
    }

    if (docsDir.existsSync()) {
      for (final entity in docsDir.listSync()) {
        if (entity is File &&
            (p.basename(entity.path).startsWith('minit') &&
                (entity.path.endsWith('.sqlite') ||
                    entity.path.endsWith('.sqlite-wal') ||
                    entity.path.endsWith('.sqlite-shm')))) {
          total += entity.lengthSync();
        }
      }
    }
    return total;
  }

  /// Deletes all audio, peaks, pending segments, and recording sidecars.
  static Future<void> deleteAllRecordingFiles() async {
    final recordingsDir = await getRecordingsDirectory();
    if (recordingsDir.existsSync()) {
      for (final entity in recordingsDir.listSync()) {
        entity.deleteSync(recursive: true);
      }
    }
    await getPendingRootDirectory();
  }

  static String _metadataPathForAudio(String audioPath) {
    final dir = p.dirname(audioPath);
    final base = p.basenameWithoutExtension(audioPath);
    return p.join(dir, '$base.json');
  }
}
