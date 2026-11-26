import 'dart:convert';

/// Marks a period (> 5s) where Android reported the microphone was silenced
/// while force recording continued.
class SilenceMarker {
  const SilenceMarker({
    required this.startMs,
    required this.endMs,
    required this.reason,
  });

  final int startMs;
  final int endMs;
  final String reason;

  int get durationMs => endMs - startMs;

  String get formattedRange =>
      '${_formatTimestamp(startMs)}-${_formatTimestamp(endMs)}';

  String get displayLabel => 'Possible silence $formattedRange';

  Map<String, dynamic> toJson() => {
        'startMs': startMs,
        'endMs': endMs,
        'reason': reason,
      };

  factory SilenceMarker.fromJson(Map<String, dynamic> json) {
    return SilenceMarker(
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      endMs: (json['endMs'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String? ?? 'Microphone silenced',
    );
  }

  static String _formatTimestamp(int ms) {
    final totalSeconds = (ms / 1000).floor().clamp(0, 864000);
    final hours = totalSeconds ~/ 3600;
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

/// Represents a finalized `.m4a` recording stored locally on the phone.
class RecordingItem {
  const RecordingItem({
    required this.id,
    required this.title,
    required this.filePath,
    required this.createdAt,
    required this.durationMs,
    required this.sizeBytes,
    required this.segmentCount,
    this.isPartial = false,
    this.isForceMode = false,
    this.silenceMarkers = const [],
    this.note,
  });

  final String id;
  final String title;
  final String filePath;
  final DateTime createdAt;
  final int durationMs;
  final int sizeBytes;
  final int segmentCount;
  final bool isPartial;
  final bool isForceMode;
  final List<SilenceMarker> silenceMarkers;
  final String? note;

  Duration get duration => Duration(milliseconds: durationMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filePath': filePath,
        'createdAt': createdAt.toIso8601String(),
        'durationMs': durationMs,
        'sizeBytes': sizeBytes,
        'segmentCount': segmentCount,
        'isPartial': isPartial,
        'isForceMode': isForceMode,
        'silenceMarkers': silenceMarkers.map((m) => m.toJson()).toList(),
        'note': note,
      };

  factory RecordingItem.fromJson(Map<String, dynamic> json) {
    final rawMarkers = json['silenceMarkers'] as List<dynamic>? ?? const [];
    return RecordingItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Recording',
      filePath: json['filePath'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      segmentCount: (json['segmentCount'] as num?)?.toInt() ?? 1,
      isPartial: json['isPartial'] as bool? ?? false,
      isForceMode: json['isForceMode'] as bool? ?? false,
      silenceMarkers: rawMarkers
          .whereType<Map>()
          .map((m) => SilenceMarker.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      note: json['note'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());
}

/// Persisted segment manifest for an in-progress recording session so
/// interrupted or killed sessions can recover every segment on disk.
class PendingSessionMetadata {
  const PendingSessionMetadata({
    required this.sessionId,
    required this.title,
    required this.createdAt,
    required this.segmentFiles,
    required this.elapsedMs,
    this.isForceMode = false,
    this.silenceMarkers = const [],
    this.note,
  });

  final String sessionId;
  final String title;
  final DateTime createdAt;
  final List<String> segmentFiles;
  final int elapsedMs;
  final bool isForceMode;
  final List<SilenceMarker> silenceMarkers;
  final String? note;

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'segmentFiles': segmentFiles,
        'elapsedMs': elapsedMs,
        'isForceMode': isForceMode,
        'silenceMarkers': silenceMarkers.map((m) => m.toJson()).toList(),
        'note': note,
      };

  factory PendingSessionMetadata.fromJson(Map<String, dynamic> json) {
    final rawMarkers = json['silenceMarkers'] as List<dynamic>? ?? const [];
    return PendingSessionMetadata(
      sessionId: json['sessionId'] as String,
      title: json['title'] as String? ?? 'Recovered Recording',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      segmentFiles: (json['segmentFiles'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      elapsedMs: (json['elapsedMs'] as num?)?.toInt() ?? 0,
      isForceMode: json['isForceMode'] as bool? ?? false,
      silenceMarkers: rawMarkers
          .whereType<Map>()
          .map((m) => SilenceMarker.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      note: json['note'] as String?,
    );
  }
}
