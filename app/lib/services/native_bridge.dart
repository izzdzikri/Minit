import 'package:flutter/services.dart';

/// Result returned after Android `MediaExtractor` + `MediaMuxer` merges
/// ADTS `.aac` segments into a single `.m4a` file.
class MergeResult {
  const MergeResult({
    required this.outputPath,
    required this.durationMs,
    required this.sizeBytes,
    required this.segmentsMerged,
    required this.sampleRate,
    required this.channelCount,
  });

  final String outputPath;
  final int durationMs;
  final int sizeBytes;
  final int segmentsMerged;
  final int sampleRate;
  final int channelCount;
}

/// Snapshot of Android's audio mode, mic-silence state, and power-saver status.
class AudioEnvironmentState {
  const AudioEnvironmentState({
    required this.audioMode,
    required this.isCallActive,
    required this.isPowerSaveMode,
    this.isClientSilenced = false,
  });

  final int audioMode;
  final bool isCallActive;
  final bool isPowerSaveMode;
  final bool isClientSilenced;
}

/// Typed Dart interface over the shared Kotlin channel in `MinuteNativeBridge.kt`.
class NativeBridge {
  NativeBridge._();

  static const MethodChannel _method = MethodChannel('com.izzdzikri.minute/native');
  static const EventChannel _events = EventChannel('com.izzdzikri.minute/audio_events');

  static Stream<Map<String, dynamic>>? _cachedStream;

  static Future<MergeResult> mergeAacSegmentsToM4a({
    required List<String> segmentPaths,
    required String outputPath,
  }) async {
    final result = await _method.invokeMapMethod<String, dynamic>(
      'mergeAacSegmentsToM4a',
      {
        'segmentPaths': segmentPaths,
        'outputPath': outputPath,
      },
    );
    if (result == null) {
      throw PlatformException(
        code: 'merge_null',
        message: 'Native merge returned no result.',
      );
    }
    return MergeResult(
      outputPath: result['outputPath'] as String? ?? outputPath,
      durationMs: (result['durationMs'] as num?)?.toInt() ?? 0,
      sizeBytes: (result['sizeBytes'] as num?)?.toInt() ?? 0,
      segmentsMerged: (result['segmentsMerged'] as num?)?.toInt() ?? 0,
      sampleRate: (result['sampleRate'] as num?)?.toInt() ?? 16000,
      channelCount: (result['channelCount'] as num?)?.toInt() ?? 1,
    );
  }

  static Future<int> getAvailableStorageBytes(String path) async {
    final bytes = await _method.invokeMethod<int>(
      'getAvailableStorageBytes',
      {'path': path},
    );
    return bytes ?? 0;
  }

  static Future<AudioEnvironmentState> getAudioEnvironmentState() async {
    final map = await _method.invokeMapMethod<String, dynamic>(
      'getAudioEnvironmentState',
    );
    return AudioEnvironmentState(
      audioMode: (map?['audioMode'] as num?)?.toInt() ?? 0,
      isCallActive: map?['isCallActive'] as bool? ?? false,
      isPowerSaveMode: map?['isPowerSaveMode'] as bool? ?? false,
      isClientSilenced: map?['isClientSilenced'] as bool? ?? false,
    );
  }

  static Future<bool> openAutoStartSettings() async {
    final opened = await _method.invokeMethod<bool>('openAutoStartSettings');
    return opened ?? false;
  }

  static Stream<Map<String, dynamic>> audioEventsStream() {
    _cachedStream ??= _events.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return event.map((k, v) => MapEntry(k.toString(), v));
      }
      return <String, dynamic>{};
    });
    return _cachedStream!;
  }
}
