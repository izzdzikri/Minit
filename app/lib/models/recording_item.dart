import 'dart:convert';

/// Types of timeline annotations stored in recording and meeting metadata.
enum MarkerType {
  marker,
  callGap,
  pauseGap,
  silence,
}

/// Represents a point marker (user-flagged moment, pause gap, call gap) or
/// range marker (silence window) along the recording's playback timeline.
class TimelineMarker {
  const TimelineMarker({
    required this.type,
    required this.startMs,
    this.endMs,
    required this.reason,
    this.gapDurationMs = 0,
  });

  final MarkerType type;
  final int startMs;
  final int? endMs;
  final String reason;
  final int gapDurationMs;

  int get effectiveEndMs => endMs ?? startMs;
  int get durationMs => (effectiveEndMs - startMs).clamp(0, 86400000);

  String get formattedStart => formatTimestamp(startMs);
  String get formattedRange =>
      '${formatTimestamp(startMs)}-${formatTimestamp(effectiveEndMs)}';

  String get shortTickLabel {
    switch (type) {
      case MarkerType.marker:
        return 'Marker';
      case MarkerType.callGap:
        return 'Call';
      case MarkerType.pauseGap:
        return 'Paused';
      case MarkerType.silence:
        return 'Silence';
    }
  }

  String get displayLabel {
    switch (type) {
      case MarkerType.silence:
        return 'Possible silence $formattedRange';
      case MarkerType.callGap:
        final dur = gapDurationMs > 0
            ? ' (${formatTimestamp(gapDurationMs)})'
            : '';
        return 'Call interruption at $formattedStart$dur';
      case MarkerType.pauseGap:
        final dur = gapDurationMs > 0
            ? ' (${formatTimestamp(gapDurationMs)})'
            : '';
        return 'Paused at $formattedStart$dur';
      case MarkerType.marker:
        final label = reason.trim().isEmpty ? 'Important moment' : reason;
        return '$label • $formattedStart';
    }
  }

  /// Plain-text marker line formatted for "Copy for AI" transcript export.
  String get exportLine {
    final ts = formatHms(startMs);
    switch (type) {
      case MarkerType.silence:
        return '[$ts] (marker: silence ${formatTimestamp(durationMs)})';
      case MarkerType.callGap:
        final dur = gapDurationMs > 0
            ? ' ${formatTimestamp(gapDurationMs)}'
            : '';
        return '[$ts] (marker: call interruption$dur)';
      case MarkerType.pauseGap:
        final dur = gapDurationMs > 0
            ? ' ${formatTimestamp(gapDurationMs)}'
            : '';
        return '[$ts] (marker: paused$dur)';
      case MarkerType.marker:
        final label = reason.trim().isEmpty ? 'flagged moment' : reason.trim();
        return '[$ts] (marker: $label)';
    }
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'startMs': startMs,
        'endMs': endMs,
        'reason': reason,
        'gapDurationMs': gapDurationMs,
      };

  factory TimelineMarker.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString();
    final type = MarkerType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => MarkerType.silence,
    );
    return TimelineMarker(
      type: type,
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      endMs: (json['endMs'] as num?)?.toInt(),
      reason: json['reason'] as String? ?? 'Event',
      gapDurationMs: (json['gapDurationMs'] as num?)?.toInt() ?? 0,
    );
  }

  static String formatTimestamp(int ms) {
    final totalSeconds = (ms / 1000).floor().clamp(0, 864000);
    final hours = totalSeconds ~/ 3600;
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  static String formatHms(int ms) {
    final totalSeconds = (ms / 1000).floor().clamp(0, 864000);
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

/// Backward-compatible alias for Phase 0 silence marker tests/imports.
typedef SilenceMarker = TimelineMarker;

/// Represents a finalized `.m4a` recording stored locally on the phone.
class RecordingItem {
  const RecordingItem({
    required this.id,
    required this.title,
    required this.filePath,
    this.peaksPath,
    required this.createdAt,
    required this.durationMs,
    required this.sizeBytes,
    required this.segmentCount,
    this.language = 'auto',
    this.isPartial = false,
    this.isForceMode = false,
    this.markers = const [],
    this.note,
  });

  final String id;
  final String title;
  final String filePath;
  final String? peaksPath;
  final DateTime createdAt;
  final int durationMs;
  final int sizeBytes;
  final int segmentCount;
  final String language;
  final bool isPartial;
  final bool isForceMode;
  final List<TimelineMarker> markers;
  final String? note;

  List<TimelineMarker> get silenceMarkers =>
      markers.where((m) => m.type == MarkerType.silence).toList();

  Duration get duration => Duration(milliseconds: durationMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filePath': filePath,
        'peaksPath': peaksPath,
        'createdAt': createdAt.toIso8601String(),
        'durationMs': durationMs,
        'sizeBytes': sizeBytes,
        'segmentCount': segmentCount,
        'language': language,
        'isPartial': isPartial,
        'isForceMode': isForceMode,
        'markers': markers.map((m) => m.toJson()).toList(),
        'note': note,
      };

  factory RecordingItem.fromJson(Map<String, dynamic> json) {
    final rawMarkers = (json['markers'] as List<dynamic>?) ??
        (json['silenceMarkers'] as List<dynamic>?) ??
        const [];
    return RecordingItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Recording',
      filePath: json['filePath'] as String,
      peaksPath: json['peaksPath'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      segmentCount: (json['segmentCount'] as num?)?.toInt() ?? 1,
      language: json['language'] as String? ?? 'auto',
      isPartial: json['isPartial'] as bool? ?? false,
      isForceMode: json['isForceMode'] as bool? ?? false,
      markers: rawMarkers
          .whereType<Map>()
          .map((m) => TimelineMarker.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      note: json['note'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());
}

/// Persisted segment manifest for an in-progress recording session so
/// interrupted or killed sessions can recover every segment and its waveform peaks.
class PendingSessionMetadata {
  const PendingSessionMetadata({
    required this.sessionId,
    required this.title,
    required this.createdAt,
    required this.segmentFiles,
    this.peaksFiles = const [],
    required this.elapsedMs,
    this.language = 'auto',
    this.isForceMode = false,
    this.markers = const [],
    this.note,
  });

  final String sessionId;
  final String title;
  final DateTime createdAt;
  final List<String> segmentFiles;
  final List<String> peaksFiles;
  final int elapsedMs;
  final String language;
  final bool isForceMode;
  final List<TimelineMarker> markers;
  final String? note;

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'segmentFiles': segmentFiles,
        'peaksFiles': peaksFiles,
        'elapsedMs': elapsedMs,
        'language': language,
        'isForceMode': isForceMode,
        'markers': markers.map((m) => m.toJson()).toList(),
        'note': note,
      };

  factory PendingSessionMetadata.fromJson(Map<String, dynamic> json) {
    final rawMarkers = (json['markers'] as List<dynamic>?) ??
        (json['silenceMarkers'] as List<dynamic>?) ??
        const [];
    return PendingSessionMetadata(
      sessionId: json['sessionId'] as String,
      title: json['title'] as String? ?? 'Recovered Recording',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      segmentFiles: (json['segmentFiles'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      peaksFiles: (json['peaksFiles'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      elapsedMs: (json['elapsedMs'] as num?)?.toInt() ?? 0,
      language: json['language'] as String? ?? 'auto',
      isForceMode: json['isForceMode'] as bool? ?? false,
      markers: rawMarkers
          .whereType<Map>()
          .map((m) => TimelineMarker.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      note: json['note'] as String?,
    );
  }
}
