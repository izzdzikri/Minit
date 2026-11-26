import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

import '../models/recording_item.dart';
import 'native_bridge.dart';
import 'recording_storage.dart';

@pragma('vm:entry-point')
void startRecordingTaskCallback() {
  FlutterForegroundTask.setTaskHandler(RecordingTaskHandler());
}

/// Foreground-service task handler that owns the microphone recording session,
/// writes continuous 30-second AAC segments to disk, monitors interruptions and
/// free storage, and merges segments into a single `.m4a` file on stop.
class RecordingTaskHandler extends TaskHandler {
  // At 16 kHz mono AAC-LC, each ADTS frame is 1024 samples = 64 ms.
  // 469 frames = 30.016 seconds of active audio per segment.
  static const int _framesPerSegment = 469;
  static const int _lowStorageWarningBytes = 50 * 1024 * 1024;
  static const int _criticalStorageBytes = 15 * 1024 * 1024;
  static const int _silenceMarkerThresholdMs = 5000;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _audioSub;
  StreamSubscription<RecordState>? _stateSub;
  StreamSubscription<RecordStop>? _stopSub;
  StreamSubscription<Map<String, dynamic>>? _nativeEventSub;

  final Stopwatch _activeStopwatch = Stopwatch();
  final List<String> _segmentPaths = <String>[];
  final List<SilenceMarker> _silenceMarkers = <SilenceMarker>[];

  String _sessionId = '';
  String _title = 'Meeting Recording';
  DateTime _createdAt = DateTime.now();
  String _sessionDir = '';
  String _recordingsDir = '';

  RandomAccessFile? _currentRaf;
  int _currentSegmentFrames = 0;
  int _totalFrames = 0;
  int _segmentIndex = 0;
  int _repeatTicks = 0;
  int _lastFreeBytes = 0;

  bool _isForceMode = false;
  bool _isPaused = false;
  bool _userInitiatedPause = false;
  bool _userPausedExplicitly = false;
  bool _userInitiatedStop = false;
  bool _finalizing = false;
  bool _isPowerSaveMode = false;

  bool _pausedByCall = false;
  bool _pausedByHeadset = false;
  int _callEndedTicks = 0;
  int _callResumeAttempts = 0;
  bool _checkingCallState = false;

  String? _statusMessage;
  String _messageLevel = 'info';
  DateTime? _lastHeadsetUnplugAt;
  String? _lastUnpluggedDeviceName;

  int? _activeSilenceStartMs;
  String? _activeSilenceReason;
  bool _notifiedOngoingSilence = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    DartPluginRegistrant.ensureInitialized();

    _createdAt = DateTime.now();
    _sessionId = 'rec_${_createdAt.millisecondsSinceEpoch}';
    _title = await FlutterForegroundTask.getData<String>(key: 'pending_title') ??
        _defaultTitle(_createdAt);
    _isForceMode =
        await FlutterForegroundTask.getData<bool>(key: 'pending_force_mode') ??
            await RecordingStorage.getForceMode();

    final recordingsDir = await RecordingStorage.getRecordingsDirectory();
    final pendingRoot = await RecordingStorage.getPendingRootDirectory();
    _recordingsDir = recordingsDir.path;
    _sessionDir = p.join(pendingRoot.path, _sessionId);
    await Directory(_sessionDir).create(recursive: true);

    _lastFreeBytes = await NativeBridge.getAvailableStorageBytes(_sessionDir);
    if (_lastFreeBytes > 0 && _lastFreeBytes < _criticalStorageBytes) {
      _statusMessage =
          'Cannot start: less than 15 MB of free storage remaining.';
      _messageLevel = 'error';
      _sendStatus(state: 'error');
      await FlutterForegroundTask.stopService();
      return;
    }

    _recorder = AudioRecorder();
    final hasPermission = await _recorder!.hasPermission(request: false);
    if (!hasPermission) {
      _statusMessage = 'Microphone permission is missing.';
      _messageLevel = 'error';
      _sendStatus(state: 'error');
      await FlutterForegroundTask.stopService();
      return;
    }

    _listenNativeEvents();
    _listenRecorderEvents();

    try {
      _openNextSegmentSync();
      _writeSessionManifestSync();

      // Mic-only capture. In force mode we ignore audio focus loss and follow
      // route changes (continuing on phone mic when a headset is unplugged).
      final config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 32000,
        audioInterruption: _isForceMode
            ? AudioInterruptionMode.none
            : AudioInterruptionMode.pause,
        audioRouteChange: _isForceMode
            ? AudioRouteChangeMode.follow
            : AudioRouteChangeMode.pause,
        androidConfig: const AndroidRecordConfig(
          useLegacy: false,
          manageBluetooth: false,
          audioSource: AndroidAudioSource.mic,
        ),
      );

      final stream = await _recorder!.startStream(config);
      _activeStopwatch.start();
      _isPaused = false;

      if (_lastFreeBytes > 0 && _lastFreeBytes < _lowStorageWarningBytes) {
        final mb = (_lastFreeBytes / (1024 * 1024)).toStringAsFixed(0);
        _statusMessage = 'Low storage warning: $mb MB free.';
        _messageLevel = 'warning';
      } else {
        _statusMessage = _isForceMode
            ? 'FORCE recording active (16 kHz mono AAC • never auto-pauses).'
            : 'Recording AAC 16 kHz mono (30s segments).';
        _messageLevel = 'info';
      }

      _audioSub = stream.listen(
        _onAudioChunk,
        onError: (Object error) {
          _handleUnexpectedInterruption(
            'Audio stream error ($error). Partial recording saved.',
          );
        },
        onDone: () {
          // Handled via onStopped/finalize when the stream ends.
        },
      );

      await _updateNotification();
      _sendStatus(state: 'recording');
    } catch (e) {
      _statusMessage = 'Failed to start recording: $e';
      _messageLevel = 'error';
      _sendStatus(state: 'error');
      await _cleanupFailedStart();
      await FlutterForegroundTask.stopService();
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_finalizing) return;
    _repeatTicks++;

    if (!_isPaused && _repeatTicks % 2 == 0) {
      _flushCurrentSegmentSync();
    }

    if (!_isPaused &&
        _activeSilenceStartMs != null &&
        !_notifiedOngoingSilence) {
      final silencedForMs =
          _activeStopwatch.elapsedMilliseconds - _activeSilenceStartMs!;
      if (silencedForMs > _silenceMarkerThresholdMs) {
        _notifiedOngoingSilence = true;
        final startLabel = SilenceMarker(
          startMs: _activeSilenceStartMs!,
          endMs: _activeSilenceStartMs!,
          reason: _activeSilenceReason ?? 'Mic silenced',
        ).formattedRange.split('-').first;
        _statusMessage =
            'Mic silenced since $startLabel (>5s) — keeping recording.';
        _messageLevel = 'warning';
      }
    }

    if (_isPaused &&
        !_isForceMode &&
        !_userPausedExplicitly &&
        !_pausedByHeadset) {
      unawaited(_checkAutoResumeAfterCall());
    }

    if (_repeatTicks % 5 == 0) {
      unawaited(_checkDeviceHealth());
    }

    unawaited(_updateNotification());
    _sendStatus(state: _isPaused ? 'paused' : 'recording');
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    final cmd = data['cmd']?.toString();
    switch (cmd) {
      case 'pause':
        unawaited(_pauseByUser());
        break;
      case 'resume':
        unawaited(_resumeByUser());
        break;
      case 'stop':
        unawaited(
          _stopAndFinalize(
            isPartial: false,
            reasonMessage: 'Recording saved.',
            callStopService: true,
          ),
        );
        break;
      case 'ping':
        _sendStatus(
          state: _finalizing
              ? 'finalizing'
              : (_isPaused ? 'paused' : 'recording'),
        );
        break;
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      unawaited(
        _stopAndFinalize(
          isPartial: false,
          reasonMessage: 'Recording stopped from notification and saved.',
          callStopService: true,
        ),
      );
    }
  }

  @override
  void onNotificationPressed() {
    // Tapping the foreground notification opens MainActivity via its PendingIntent.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    if (!_finalizing) {
      await _stopAndFinalize(
        isPartial: true,
        reasonMessage: isTimeout
            ? 'Foreground service timed out — partial recording saved.'
            : 'Recording stopped — partial audio saved.',
        callStopService: false,
      );
    }
  }

  void _listenNativeEvents() {
    _nativeEventSub = NativeBridge.audioEventsStream().listen((event) {
      final type = event['type']?.toString();
      if (type == 'headset_unplugged') {
        _lastHeadsetUnplugAt = DateTime.now();
        _lastUnpluggedDeviceName =
            event['deviceName']?.toString() ?? 'Headset';
        if (!_isPaused && !_finalizing) {
          _statusMessage = _isForceMode
              ? '$_lastUnpluggedDeviceName unplugged — continuing on phone mic (FORCE).'
              : '$_lastUnpluggedDeviceName unplugged — keeping audio safe.';
          _messageLevel = _isForceMode ? 'info' : 'warning';
          _sendStatus(state: 'recording');
        }
      } else if (type == 'mic_silenced') {
        final silenced = event['silenced'] as bool? ?? true;
        final isCall = event['isCallActive'] as bool? ?? false;
        if (silenced) {
          if (_activeSilenceStartMs == null && !_isPaused && !_finalizing) {
            _activeSilenceStartMs = _activeStopwatch.elapsedMilliseconds;
            _activeSilenceReason = isCall
                ? 'Phone/VoIP call silenced mic'
                : 'Another app/system silenced mic';
            _notifiedOngoingSilence = false;
          }
        } else {
          _closeActiveSilenceWindow();
        }
      }
    });
  }

  void _listenRecorderEvents() {
    final recorder = _recorder;
    if (recorder == null) return;

    _stateSub = recorder.onStateChanged().listen((state) {
      if (_finalizing) return;

      if (state == RecordState.pause) {
        _closeActiveSilenceWindow();
        _activeStopwatch.stop();
        _isPaused = true;
        _flushCurrentSegmentSync();
        _writeSessionManifestSync();

        if (_userInitiatedPause) {
          _userInitiatedPause = false;
          _userPausedExplicitly = true;
          _pausedByCall = false;
          _pausedByHeadset = false;
          _statusMessage = 'Recording paused. Segments flushed to disk.';
          _messageLevel = 'info';
          _sendStatus(state: 'paused');
          unawaited(_updateNotification());
        } else if (_isForceMode) {
          // Force mode must never stay auto-paused; immediately resume on phone mic.
          unawaited(_forceResumeImmediately());
        } else {
          unawaited(_classifyAndReportPauseInterruption());
        }
      } else if (state == RecordState.record) {
        final wasCallPaused = _pausedByCall;
        _activeStopwatch.start();
        _isPaused = false;
        _userPausedExplicitly = false;
        _pausedByCall = false;
        _pausedByHeadset = false;
        _callEndedTicks = 0;
        _callResumeAttempts = 0;
        _statusMessage = wasCallPaused
            ? 'Call ended — recording auto-resumed.'
            : (_isForceMode
                ? 'FORCE recording active (16 kHz mono AAC).'
                : 'Recording resumed.');
        _messageLevel = 'info';
        _sendStatus(state: 'recording');
        unawaited(_updateNotification());
      }
    });

    _stopSub = recorder.onStopped().listen((stop) {
      if (_userInitiatedStop || _finalizing) return;

      final detail = stop.error?.isNotEmpty == true
          ? stop.error!
          : stop.reason.name;
      _handleUnexpectedInterruption(
        'Recording interrupted ($detail) — partial recording saved.',
      );
    });
  }

  Future<void> _forceResumeImmediately() async {
    try {
      await _recorder?.resume();
    } catch (e) {
      _statusMessage = 'FORCE mode resume retry pending: $e';
      _messageLevel = 'warning';
      _sendStatus(state: 'paused');
    }
  }

  Future<void> _classifyAndReportPauseInterruption() async {
    final now = DateTime.now();
    final recentUnplug = _lastHeadsetUnplugAt != null &&
        now.difference(_lastHeadsetUnplugAt!).inSeconds <= 3;

    if (recentUnplug) {
      _pausedByHeadset = true;
      _pausedByCall = false;
      final name = _lastUnpluggedDeviceName ?? 'Headset';
      _statusMessage =
          'Paused: $name unplugged. Audio saved safely — tap Resume for phone mic or Stop to save.';
      _messageLevel = 'warning';
    } else {
      final env = await NativeBridge.getAudioEnvironmentState();
      if (env.isCallActive) {
        _pausedByCall = true;
        _pausedByHeadset = false;
        _callEndedTicks = 0;
        _callResumeAttempts = 0;
        _statusMessage =
            'Paused: incoming phone or VoIP call detected. Will auto-resume when the call ends.';
      } else {
        _pausedByCall = false;
        _pausedByHeadset = false;
        _statusMessage =
            'Paused: another app took audio focus. Audio saved safely — tap Resume or Stop.';
      }
      _messageLevel = 'warning';
    }

    await _updateNotification();
    _sendStatus(state: 'paused');
  }

  Future<void> _checkAutoResumeAfterCall() async {
    if (_checkingCallState ||
        _finalizing ||
        !_isPaused ||
        _userPausedExplicitly ||
        _pausedByHeadset ||
        _isForceMode) {
      return;
    }
    _checkingCallState = true;
    try {
      final env = await NativeBridge.getAudioEnvironmentState();
      if (env.isCallActive) {
        if (!_pausedByCall) {
          _pausedByCall = true;
          _statusMessage =
              'Paused: call in progress. Will auto-resume when the call ends.';
          _messageLevel = 'warning';
          await _updateNotification();
          _sendStatus(state: 'paused');
        }
        _callEndedTicks = 0;
        return;
      }

      if (_pausedByCall && !env.isCallActive) {
        _callEndedTicks++;
        if (_callEndedTicks >= 1 && _callResumeAttempts < 4) {
          _callResumeAttempts++;
          try {
            await _recorder?.resume();
          } catch (_) {
            if (_callResumeAttempts >= 4) {
              _pausedByCall = false;
              _statusMessage =
                  'Call ended, but mic could not auto-resume. Tap Resume or Stop to save.';
              _messageLevel = 'warning';
              _sendStatus(state: 'paused');
            }
          }
        }
      }
    } catch (_) {
      // Ignore transient query errors; next repeat tick will retry.
    } finally {
      _checkingCallState = false;
    }
  }

  void _closeActiveSilenceWindow() {
    final startMs = _activeSilenceStartMs;
    if (startMs == null) return;
    final reason = _activeSilenceReason ?? 'System or another app silenced mic';
    _activeSilenceStartMs = null;
    _activeSilenceReason = null;
    _notifiedOngoingSilence = false;

    final endMs = _activeStopwatch.elapsedMilliseconds;
    if (endMs - startMs > _silenceMarkerThresholdMs) {
      final marker = SilenceMarker(
        startMs: startMs,
        endMs: endMs,
        reason: reason,
      );
      _silenceMarkers.add(marker);
      _writeSessionManifestSync();
      if (!_finalizing) {
        _statusMessage = 'Marked: ${marker.displayLabel}.';
        _messageLevel = 'warning';
        _sendStatus(state: _isPaused ? 'paused' : 'recording');
      }
    }
  }

  Future<void> _pauseByUser() async {
    if (_finalizing || _isPaused) return;
    _userInitiatedPause = true;
    try {
      await _recorder?.pause();
    } catch (e) {
      _userInitiatedPause = false;
      _statusMessage = 'Could not pause: $e';
      _messageLevel = 'error';
      _sendStatus(state: _isPaused ? 'paused' : 'recording');
    }
  }

  Future<void> _resumeByUser() async {
    if (_finalizing || !_isPaused) return;
    _userPausedExplicitly = false;
    _pausedByCall = false;
    _pausedByHeadset = false;
    try {
      await _recorder?.resume();
    } catch (e) {
      _statusMessage =
          'Cannot resume yet (microphone busy or unavailable): $e';
      _messageLevel = 'warning';
      _sendStatus(state: 'paused');
    }
  }

  void _onAudioChunk(Uint8List chunk) {
    if (_finalizing || chunk.isEmpty) return;

    try {
      if (_currentRaf == null) {
        _openNextSegmentSync();
      }
      _currentRaf!.writeFromSync(chunk);
      _currentSegmentFrames++;
      _totalFrames++;

      if (_currentSegmentFrames >= _framesPerSegment) {
        _closeCurrentSegmentSync();
        _openNextSegmentSync();
        _writeSessionManifestSync();
      }
    } on FileSystemException catch (e) {
      _handleUnexpectedInterruption(
        'Storage write error (${e.message}). Partial recording saved.',
      );
    }
  }

  void _openNextSegmentSync() {
    _segmentIndex++;
    final fileName = 'seg_${_segmentIndex.toString().padLeft(4, '0')}.aac';
    final segPath = p.join(_sessionDir, fileName);
    final file = File(segPath);
    _currentRaf = file.openSync(mode: FileMode.writeOnlyAppend);
    _currentSegmentFrames = 0;
    _segmentPaths.add(segPath);
  }

  void _flushCurrentSegmentSync() {
    try {
      _currentRaf?.flushSync();
    } catch (_) {}
  }

  void _closeCurrentSegmentSync() {
    try {
      _currentRaf?.flushSync();
    } catch (_) {}
    try {
      _currentRaf?.closeSync();
    } catch (_) {}
    _currentRaf = null;
    _currentSegmentFrames = 0;
  }

  void _writeSessionManifestSync() {
    if (_sessionDir.isEmpty) return;
    try {
      final meta = PendingSessionMetadata(
        sessionId: _sessionId,
        title: _title,
        createdAt: _createdAt,
        segmentFiles: _segmentPaths.map(p.basename).toList(),
        elapsedMs: _activeStopwatch.elapsedMilliseconds,
        isForceMode: _isForceMode,
        silenceMarkers: List<SilenceMarker>.unmodifiable(_silenceMarkers),
        note: _statusMessage,
      );
      final metaPath = p.join(_sessionDir, 'session.json');
      final tmpFile = File('$metaPath.tmp');
      tmpFile.writeAsStringSync(jsonEncode(meta.toJson()), flush: true);
      tmpFile.renameSync(metaPath);
    } catch (_) {}
  }

  Future<void> _checkDeviceHealth() async {
    if (_finalizing || _sessionDir.isEmpty) return;
    try {
      final freeBytes = await NativeBridge.getAvailableStorageBytes(_sessionDir);
      final env = await NativeBridge.getAudioEnvironmentState();
      _lastFreeBytes = freeBytes;
      _isPowerSaveMode = env.isPowerSaveMode;

      // Safety stop (< 15 MB) applies in both Normal and Force modes.
      if (freeBytes > 0 && freeBytes < _criticalStorageBytes) {
        await _stopAndFinalize(
          isPartial: true,
          reasonMessage:
              'Stopped automatically: storage critically low (< 15 MB free). Partial recording saved.',
          callStopService: true,
        );
        return;
      }

      if (freeBytes > 0 &&
          freeBytes < _lowStorageWarningBytes &&
          _messageLevel == 'info') {
        final mb = (freeBytes / (1024 * 1024)).toStringAsFixed(0);
        _statusMessage = 'Low storage warning: $mb MB free.';
        _messageLevel = 'warning';
      }
    } catch (_) {}
  }

  void _handleUnexpectedInterruption(String message) {
    if (_finalizing) return;
    unawaited(
      _stopAndFinalize(
        isPartial: true,
        reasonMessage: message,
        callStopService: true,
      ),
    );
  }

  Future<void> _stopAndFinalize({
    required bool isPartial,
    required String reasonMessage,
    required bool callStopService,
  }) async {
    if (_finalizing) return;
    _finalizing = true;
    _userInitiatedStop = true;
    _activeStopwatch.stop();
    _closeActiveSilenceWindow();

    _statusMessage = 'Finalizing and merging audio segments...';
    _messageLevel = isPartial ? 'warning' : 'info';
    _sendStatus(state: 'finalizing');

    await _audioSub?.cancel();
    _audioSub = null;
    await _stateSub?.cancel();
    _stateSub = null;
    await _stopSub?.cancel();
    _stopSub = null;
    await _nativeEventSub?.cancel();
    _nativeEventSub = null;

    try {
      if (_recorder != null && await _recorder!.isRecording()) {
        await _recorder!.stop();
      }
    } catch (_) {}

    try {
      await _recorder?.dispose();
    } catch (_) {}
    _recorder = null;

    _closeCurrentSegmentSync();
    _writeSessionManifestSync();

    final nonEmptySegments = _segmentPaths
        .where((path) => File(path).existsSync() && File(path).lengthSync() > 7)
        .toList();

    if (nonEmptySegments.isNotEmpty) {
      final outputPath = p.join(_recordingsDir, '$_sessionId.m4a');
      try {
        final merged = await NativeBridge.mergeAacSegmentsToM4a(
          segmentPaths: nonEmptySegments,
          outputPath: outputPath,
        );
        final item = RecordingItem(
          id: _sessionId,
          title: isPartial ? '$_title (Partial)' : _title,
          filePath: merged.outputPath,
          createdAt: _createdAt,
          durationMs: merged.durationMs > 0
              ? merged.durationMs
              : _activeStopwatch.elapsedMilliseconds,
          sizeBytes: merged.sizeBytes,
          segmentCount: merged.segmentsMerged,
          isPartial: isPartial,
          isForceMode: _isForceMode,
          silenceMarkers: List<SilenceMarker>.unmodifiable(_silenceMarkers),
          note: isPartial ? reasonMessage : null,
        );
        await RecordingStorage.saveMetadata(item);

        try {
          await Directory(_sessionDir).delete(recursive: true);
        } catch (_) {}

        FlutterForegroundTask.sendDataToMain({
          'event': 'saved',
          'recording': item.toJson(),
          'message': reasonMessage,
          'messageLevel': isPartial ? 'warning' : 'info',
        });
      } catch (e) {
        FlutterForegroundTask.sendDataToMain({
          'event': 'status',
          'state': 'error',
          'elapsedMs': _activeStopwatch.elapsedMilliseconds,
          'segmentCount': nonEmptySegments.length,
          'freeBytes': _lastFreeBytes,
          'isPowerSaveMode': _isPowerSaveMode,
          'isForceMode': _isForceMode,
          'message':
              'Merge failed ($e). Raw segments kept in pending folder for recovery.',
          'messageLevel': 'error',
        });
      }
    } else {
      try {
        await Directory(_sessionDir).delete(recursive: true);
      } catch (_) {}
      FlutterForegroundTask.sendDataToMain({
        'event': 'status',
        'state': 'stopped',
        'elapsedMs': 0,
        'segmentCount': 0,
        'freeBytes': _lastFreeBytes,
        'isPowerSaveMode': _isPowerSaveMode,
        'isForceMode': _isForceMode,
        'message': 'No audio frames were captured.',
        'messageLevel': 'warning',
      });
    }

    if (callStopService) {
      await FlutterForegroundTask.stopService();
    }
  }

  Future<void> _cleanupFailedStart() async {
    await _audioSub?.cancel();
    await _stateSub?.cancel();
    await _stopSub?.cancel();
    await _nativeEventSub?.cancel();
    try {
      await _recorder?.dispose();
    } catch (_) {}
    _recorder = null;
    _closeCurrentSegmentSync();
  }

  Future<void> _updateNotification() async {
    final elapsed = _formatElapsed(_activeStopwatch.elapsed);
    final segCount = _segmentPaths.length;
    final stateLabel = _isPaused ? 'Paused' : 'Recording';
    final titlePrefix = _isForceMode ? 'Minute • FORCE $stateLabel' : 'Minute • $stateLabel';
    final forceTag = _isForceMode ? 'FORCE • ' : '';
    await FlutterForegroundTask.updateService(
      notificationTitle: titlePrefix,
      notificationText: '$forceTag$elapsed • $segCount segment(s) • 16 kHz AAC',
    );
  }

  void _sendStatus({required String state}) {
    FlutterForegroundTask.sendDataToMain({
      'event': 'status',
      'state': state,
      'elapsedMs': _activeStopwatch.elapsedMilliseconds,
      'segmentCount': _segmentPaths.length,
      'totalFrames': _totalFrames,
      'freeBytes': _lastFreeBytes,
      'isPowerSaveMode': _isPowerSaveMode,
      'isForceMode': _isForceMode,
      'silenceCount': _silenceMarkers.length,
      'message': _statusMessage,
      'messageLevel': _messageLevel,
    });
  }

  static String _defaultTitle(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return 'Recording $h:$m';
  }

  static String _formatElapsed(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
