import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/database/app_database.dart';
import '../data/repositories/meeting_repository.dart';
import '../models/recording_item.dart';
import '../services/app_settings.dart';
import '../services/native_bridge.dart';
import '../services/peaks_storage.dart';
import '../services/permissions_service.dart';
import '../services/playback_controller.dart';
import '../services/recording_storage.dart';
import '../services/recording_task_handler.dart';
import '../widgets/waveform_view.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => unawaited(db.close()));
  return db;
});

final meetingRepositoryProvider = Provider<MeetingRepository>((ref) {
  return MeetingRepository(ref.watch(appDatabaseProvider));
});

final playbackControllerProvider = Provider<PlaybackController>((ref) {
  final controller = PlaybackController();
  unawaited(controller.init());
  ref.onDispose(controller.dispose);
  return controller;
});

final connectivityOnlineProvider =
    NotifierProvider<ConnectivityNotifier, bool>(ConnectivityNotifier.new);

class ConnectivityNotifier extends Notifier<bool> {
  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  bool build() {
    unawaited(_init());
    ref.onDispose(() => unawaited(_sub?.cancel() ?? Future<void>.value()));
    return true;
  }

  Future<void> _init() async {
    final online = await NativeBridge.isNetworkOnline();
    state = online;
    try {
      _sub = NativeBridge.audioEventsStream().listen((event) {
        if (event['type'] == 'connectivity') {
          state = event['isOnline'] as bool? ?? true;
        }
      });
    } catch (_) {}
  }

  Future<void> refresh() async {
    state = await NativeBridge.isNetworkOnline();
  }
}

final sessionConsentProvider =
    NotifierProvider<SessionConsentNotifier, bool>(SessionConsentNotifier.new);

class SessionConsentNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markConsented() => state = true;
}

typedef SettingsPersistCallback = Future<void> Function(AppSettings settings);
typedef ForceModeServiceSyncCallback = Future<void> Function(bool enabled);

final settingsPersistProvider = Provider<SettingsPersistCallback>((ref) {
  return AppSettingsStorage.save;
});

final forceModeServiceSyncProvider =
    Provider<ForceModeServiceSyncCallback>((ref) {
  return (bool enabled) async {
    final saved = await FlutterForegroundTask.saveData(
      key: 'pending_force_mode',
      value: enabled,
    );
    if (!saved) {
      throw StateError('Failed to persist service force mode flag.');
    }
    FlutterForegroundTask.sendDataToTask({
      'cmd': 'set_force_mode',
      'enabled': enabled,
    });
  };
});

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    return AppSettingsStorage.load();
  }

  Future<String?> _applyOptimisticUpdate(
    AppSettings Function(AppSettings current) transform, {
    required String errorMessage,
    Future<void> Function(AppSettings updated)? afterPersist,
    VoidCallback? onRevert,
  }) async {
    final previous = state.value ?? const AppSettings();
    final updated = transform(previous);
    if (_sameSettings(previous, updated)) {
      return null;
    }

    // Update UI state synchronously before starting background persistence.
    state = AsyncData(updated);
    try {
      await ref.read(settingsPersistProvider)(updated);
      if (afterPersist != null) {
        await afterPersist(updated);
      }
      return null;
    } catch (_) {
      state = AsyncData(previous);
      onRevert?.call();
      return errorMessage;
    }
  }

  static bool _sameSettings(AppSettings a, AppSettings b) {
    return a.themePreference == b.themePreference &&
        a.defaultLanguage == b.defaultLanguage &&
        a.otherAppAudioBehavior == b.otherAppAudioBehavior &&
        a.forceRecordMode == b.forceRecordMode;
  }

  Future<String?> setThemePreference(ThemeMode mode) => _applyOptimisticUpdate(
        (current) => current.copyWith(themePreference: mode),
        errorMessage: 'Could not save theme preference.',
      );

  Future<String?> setDefaultLanguage(String language) =>
      _applyOptimisticUpdate(
        (current) => current.copyWith(defaultLanguage: language),
        errorMessage: 'Could not save default language.',
      );

  Future<String?> setOtherAppAudioBehavior(OtherAppAudioBehavior behavior) =>
      _applyOptimisticUpdate(
        (current) => current.copyWith(otherAppAudioBehavior: behavior),
        errorMessage: 'Could not save audio interruption preference.',
      );

  Future<String?> setForceRecordMode(bool enabled) {
    final recNotifier = ref.read(recordingControllerProvider.notifier);
    final recState = ref.read(recordingControllerProvider);
    final wasActive = recState.isActive;
    final prevRecForce = recState.isForceMode;
    if (wasActive) {
      recNotifier.setForceModeOptimistic(enabled);
    }

    return _applyOptimisticUpdate(
      (current) => current.copyWith(forceRecordMode: enabled),
      errorMessage: 'Could not update Force record mode.',
      afterPersist: wasActive
          ? (updated) =>
              ref.read(forceModeServiceSyncProvider)(updated.forceRecordMode)
          : null,
      onRevert: wasActive
          ? () => recNotifier.setForceModeOptimistic(prevRecForce)
          : null,
    );
  }

  Future<void> reload() async {
    state = AsyncData(await AppSettingsStorage.load());
  }
}

final libraryQueryProvider =
    NotifierProvider<LibraryQueryNotifier, String>(LibraryQueryNotifier.new);

class LibraryQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
}

final meetingsProvider =
    AsyncNotifierProvider<MeetingsNotifier, List<MeetingListItem>>(
  MeetingsNotifier.new,
);

class MeetingsNotifier extends AsyncNotifier<List<MeetingListItem>> {
  String? _lastRecoveryMessage;

  String? takeRecoveryMessage() {
    final msg = _lastRecoveryMessage;
    _lastRecoveryMessage = null;
    return msg;
  }

  @override
  Future<List<MeetingListItem>> build() async {
    final repo = ref.watch(meetingRepositoryProvider);
    final query = ref.watch(libraryQueryProvider);

    bool running = false;
    try {
      running = await FlutterForegroundTask.isRunningService;
    } catch (_) {}

    await repo.purgeSoftDeleted();
    final recovered = await repo.syncFromDisk(serviceIsRunning: running);
    if (recovered.isNotEmpty) {
      _lastRecoveryMessage =
          'Recovered ${recovered.length} interrupted recording(s) with waveform peaks.';
    }
    return repo.listMeetings(query: query);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(meetingRepositoryProvider);
      final query = ref.read(libraryQueryProvider);
      bool running = false;
      try {
        running = await FlutterForegroundTask.isRunningService;
      } catch (_) {}
      await repo.syncFromDisk(serviceIsRunning: running);
      return repo.listMeetings(query: query);
    });
  }

  Future<String> addDemoMeeting() async {
    final repo = ref.read(meetingRepositoryProvider);
    final id = await repo.createDemoMeeting();
    ref.invalidateSelf();
    return id;
  }

  Future<void> softDelete(String id) async {
    final repo = ref.read(meetingRepositoryProvider);
    await repo.softDeleteMeeting(id);
    final query = ref.read(libraryQueryProvider);
    state = AsyncData(await repo.listMeetings(query: query));
  }

  Future<void> restore(String id) async {
    final repo = ref.read(meetingRepositoryProvider);
    await repo.restoreMeeting(id);
    final query = ref.read(libraryQueryProvider);
    state = AsyncData(await repo.listMeetings(query: query));
  }

  Future<void> commitHardDelete(String id) async {
    final repo = ref.read(meetingRepositoryProvider);
    final detail = await repo.getMeetingDetail(id);
    if (detail != null &&
        ref.read(playbackControllerProvider).currentMeetingId == id) {
      await ref.read(playbackControllerProvider).stop();
    }
    await repo.commitHardDelete(id);
  }

  Future<void> deleteAllData() async {
    await ref.read(playbackControllerProvider).stop();
    await ref.read(meetingRepositoryProvider).deleteAllData();
    ref.invalidateSelf();
  }
}

final meetingDetailProvider =
    FutureProvider.autoDispose.family<MeetingDetailData?, String>((ref, id) {
  return ref.watch(meetingRepositoryProvider).getMeetingDetail(id);
});

final meetingPeaksProvider =
    FutureProvider.autoDispose.family<Uint8List?, String?>((ref, peaksPath) {
  return PeaksStorage.readPeaksFile(peaksPath);
});

enum RecorderStatus { idle, recording, paused, finalizing }

class RecordingUiState {
  const RecordingUiState({
    this.status = RecorderStatus.idle,
    this.elapsed = Duration.zero,
    this.segmentCount = 0,
    this.freeBytes = 0,
    this.isPowerSaveMode = false,
    this.isForceMode = false,
    this.language = 'auto',
    this.title = '',
    this.markers = const [],
    this.statusMessage,
    this.messageLevel = 'info',
    this.oemInfo,
    this.ignoringBatteryOpt = true,
    this.lastSavedMeetingId,
    this.openRecordRequestSeq = 0,
  });

  final RecorderStatus status;
  final Duration elapsed;
  final int segmentCount;
  final int freeBytes;
  final bool isPowerSaveMode;
  final bool isForceMode;
  final String language;
  final String title;
  final List<TimelineMarker> markers;
  final String? statusMessage;
  final String messageLevel;
  final OemDeviceInfo? oemInfo;
  final bool ignoringBatteryOpt;
  final String? lastSavedMeetingId;
  final int openRecordRequestSeq;

  bool get isActive =>
      status == RecorderStatus.recording ||
      status == RecorderStatus.paused ||
      status == RecorderStatus.finalizing;

  RecordingUiState copyWith({
    RecorderStatus? status,
    Duration? elapsed,
    int? segmentCount,
    int? freeBytes,
    bool? isPowerSaveMode,
    bool? isForceMode,
    String? language,
    String? title,
    List<TimelineMarker>? markers,
    String? statusMessage,
    bool clearMessage = false,
    String? messageLevel,
    OemDeviceInfo? oemInfo,
    bool? ignoringBatteryOpt,
    String? lastSavedMeetingId,
    bool clearLastSaved = false,
    int? openRecordRequestSeq,
  }) {
    return RecordingUiState(
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      segmentCount: segmentCount ?? this.segmentCount,
      freeBytes: freeBytes ?? this.freeBytes,
      isPowerSaveMode: isPowerSaveMode ?? this.isPowerSaveMode,
      isForceMode: isForceMode ?? this.isForceMode,
      language: language ?? this.language,
      title: title ?? this.title,
      markers: markers ?? this.markers,
      statusMessage:
          clearMessage ? null : (statusMessage ?? this.statusMessage),
      messageLevel: messageLevel ?? this.messageLevel,
      oemInfo: oemInfo ?? this.oemInfo,
      ignoringBatteryOpt: ignoringBatteryOpt ?? this.ignoringBatteryOpt,
      lastSavedMeetingId: clearLastSaved
          ? null
          : (lastSavedMeetingId ?? this.lastSavedMeetingId),
      openRecordRequestSeq: openRecordRequestSeq ?? this.openRecordRequestSeq,
    );
  }
}

final liveWaveformControllerProvider =
    Provider<LiveWaveformController>((ref) {
  final controller = LiveWaveformController();
  ref.onDispose(controller.dispose);
  return controller;
});

final recordingControllerProvider =
    NotifierProvider<RecordingController, RecordingUiState>(
  RecordingController.new,
);

class RecordingController extends Notifier<RecordingUiState> {
  bool _registeredCallback = false;

  LiveWaveformController get _waveform =>
      ref.read(liveWaveformControllerProvider);

  @override
  RecordingUiState build() {
    if (!_registeredCallback) {
      _registeredCallback = true;
      FlutterForegroundTask.addTaskDataCallback(_onTaskData);
      ref.onDispose(() {
        FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
      });
    }
    unawaited(refreshDeviceStatus());
    unawaited(syncWithRunningService());
    return const RecordingUiState();
  }

  Future<void> refreshDeviceStatus() async {
    try {
      final oem = await PermissionsService.getOemDeviceInfo();
      final ignoringBattery =
          await PermissionsService.isIgnoringBatteryOptimizations();
      final dir = await RecordingStorage.getRecordingsDirectory();
      final freeBytes = await NativeBridge.getAvailableStorageBytes(dir.path);
      final env = await NativeBridge.getAudioEnvironmentState();
      state = state.copyWith(
        oemInfo: oem,
        ignoringBatteryOpt: ignoringBattery,
        freeBytes: freeBytes,
        isPowerSaveMode: env.isPowerSaveMode,
      );
    } catch (_) {}
  }

  Future<void> syncWithRunningService() async {
    try {
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (isRunning) {
        if (state.status == RecorderStatus.idle) {
          state = state.copyWith(status: RecorderStatus.recording);
        }
        FlutterForegroundTask.sendDataToTask({'cmd': 'ping'});
      } else if (state.status != RecorderStatus.idle) {
        state = state.copyWith(status: RecorderStatus.idle);
      }
    } catch (_) {}
  }

  void setDraftTitle(String title) {
    state = state.copyWith(title: title);
    if (state.isActive) {
      FlutterForegroundTask.sendDataToTask({'cmd': 'update_meta', 'title': title});
    }
  }

  void setDraftLanguage(String language) {
    state = state.copyWith(language: language);
    if (state.isActive) {
      FlutterForegroundTask.sendDataToTask({
        'cmd': 'update_meta',
        'language': language,
      });
    }
  }

  void clearLastSaved() {
    state = state.copyWith(clearLastSaved: true);
  }

  void setForceModeOptimistic(bool enabled) {
    if (state.isForceMode == enabled) return;
    state = state.copyWith(isForceMode: enabled);
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  Future<bool> startRecording({
    required BuildContext context,
    required String title,
    required String language,
    required bool forceMode,
  }) async {
    if (state.isActive) return false;

    final playback = ref.read(playbackControllerProvider);
    if (playback.isPlaying) {
      await playback.stop();
    }
    if (!context.mounted) return false;

    final granted =
        await PermissionsService.ensureRecordingPermissions(context);
    if (!granted || !context.mounted) return false;

    if (state.oemInfo?.needsAggressiveBackgroundHelp == true &&
        !state.ignoringBatteryOpt) {
      await PermissionsService.requestBatteryOptimizationExemption(context);
      await refreshDeviceStatus();
    }

    final dir = await RecordingStorage.getRecordingsDirectory();
    final freeBytes = await NativeBridge.getAvailableStorageBytes(dir.path);
    if (freeBytes > 0 && freeBytes < 20 * 1024 * 1024) {
      state = state.copyWith(
        freeBytes: freeBytes,
        statusMessage:
            'Not enough free storage (< 20 MB). Free up space before recording.',
        messageLevel: 'error',
      );
      return false;
    }

    final now = DateTime.now();
    final effectiveTitle = title.trim().isNotEmpty
        ? title.trim()
        : 'Recording ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    await FlutterForegroundTask.saveData(
      key: 'pending_title',
      value: effectiveTitle,
    );
    await FlutterForegroundTask.saveData(
      key: 'pending_language',
      value: language,
    );
    await FlutterForegroundTask.saveData(
      key: 'pending_force_mode',
      value: forceMode,
    );

    _waveform.reset();

    final result = await FlutterForegroundTask.startService(
      serviceId: 1001,
      serviceTypes: [ForegroundServiceTypes.microphone],
      notificationTitle:
          forceMode ? 'Minit • FORCE Recording' : 'Minit • Recording',
      notificationText: forceMode
          ? 'FORCE • 00:00 • Starting 16 kHz AAC capture...'
          : '00:00 • Starting 16 kHz AAC capture...',
      notificationButtons: const [
        NotificationButton(id: 'stop', text: 'Stop'),
      ],
      notificationInitialRoute: '/library/record',
      callback: startRecordingTaskCallback,
    );

    if (result is ServiceRequestSuccess) {
      state = state.copyWith(
        status: RecorderStatus.recording,
        elapsed: Duration.zero,
        segmentCount: 1,
        isForceMode: forceMode,
        language: language,
        title: effectiveTitle,
        markers: const [],
        clearLastSaved: true,
        statusMessage: forceMode
            ? 'FORCE recording started (never auto-pauses).'
            : 'Recording started.',
        messageLevel: 'info',
      );
      return true;
    } else if (result is ServiceRequestFailure) {
      state = state.copyWith(
        statusMessage: 'Could not start recording service: ${result.error}',
        messageLevel: 'error',
      );
      return false;
    }
    return false;
  }

  void togglePauseResume() {
    if (state.status == RecorderStatus.recording) {
      FlutterForegroundTask.sendDataToTask({'cmd': 'pause'});
    } else if (state.status == RecorderStatus.paused) {
      FlutterForegroundTask.sendDataToTask({'cmd': 'resume'});
    }
  }

  void addMarker([String? label]) {
    if (!state.isActive || state.status == RecorderStatus.finalizing) return;
    FlutterForegroundTask.sendDataToTask({
      'cmd': 'add_marker',
      'label': label ?? 'Important moment',
    });
  }

  void stopRecording() {
    if (!state.isActive || state.status == RecorderStatus.finalizing) return;
    state = state.copyWith(
      status: RecorderStatus.finalizing,
      statusMessage: 'Saving audio and waveform peaks...',
      messageLevel: 'info',
    );
    FlutterForegroundTask.sendDataToTask({'cmd': 'stop'});
  }

  void _onTaskData(Object data) {
    if (data is! Map) return;
    final event = data['event']?.toString();

    if (event == 'levels') {
      final rawSamples = data['samples'];
      final elapsedMs = (data['elapsedMs'] as num?)?.toInt() ?? 0;
      if (rawSamples is List && rawSamples.isNotEmpty) {
        final samples = <double>[
          for (final v in rawSamples)
            if (v is num) v.toDouble(),
        ];
        _waveform.addSamples(samples, elapsedMs: elapsedMs);
      }
      return;
    }

    if (event == 'level') {
      final level = (data['level'] as num?)?.toDouble() ?? 0.0;
      final elapsedMs = (data['elapsedMs'] as num?)?.toInt() ?? 0;
      _waveform.addSample(level, elapsedMs: elapsedMs);
      return;
    }

    if (event == 'status') {
      final stateStr = data['state']?.toString() ?? 'idle';
      final elapsedMs = (data['elapsedMs'] as num?)?.toInt() ?? 0;
      final segments = (data['segmentCount'] as num?)?.toInt() ?? 0;
      final freeBytes = (data['freeBytes'] as num?)?.toInt() ?? state.freeBytes;
      final powerSave = data['isPowerSaveMode'] as bool? ?? state.isPowerSaveMode;
      final isForce = data['isForceMode'] as bool? ?? state.isForceMode;
      final msg = data['message']?.toString();
      final level = data['messageLevel']?.toString() ?? 'info';
      final rawMarkers = data['markers'] as List<dynamic>?;
      final markers = rawMarkers != null
          ? rawMarkers
              .whereType<Map>()
              .map((m) => TimelineMarker.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : state.markers;

      final nextStatus = switch (stateStr) {
        'recording' => RecorderStatus.recording,
        'paused' => RecorderStatus.paused,
        'finalizing' => RecorderStatus.finalizing,
        _ => RecorderStatus.idle,
      };

      final recentLevelsRaw = data['recentLevels'] as List<dynamic>?;
      if (recentLevelsRaw != null) {
        _waveform.setHistory(
          recentLevelsRaw.map((e) => (e as num).toDouble()).toList(),
          elapsedMs: elapsedMs,
          paused: nextStatus == RecorderStatus.paused,
          markers: markers,
        );
      } else if (rawMarkers != null ||
          _waveform.isPaused != (nextStatus == RecorderStatus.paused)) {
        _waveform.updateState(
          paused: nextStatus == RecorderStatus.paused,
          elapsedMs: elapsedMs,
          markers: rawMarkers != null ? markers : null,
        );
      }

      final nextMessage =
          (msg != null && msg.isNotEmpty) ? msg : state.statusMessage;
      final elapsedChanged = nextStatus == RecorderStatus.recording
          ? state.elapsed.inSeconds != (elapsedMs ~/ 1000)
          : state.elapsed.inMilliseconds != elapsedMs;

      if (state.status == nextStatus &&
          !elapsedChanged &&
          state.segmentCount == segments &&
          state.freeBytes == freeBytes &&
          state.isPowerSaveMode == powerSave &&
          state.isForceMode == isForce &&
          rawMarkers == null &&
          state.statusMessage == nextMessage &&
          state.messageLevel == level) {
        return;
      }

      state = state.copyWith(
        status: nextStatus,
        elapsed: Duration(milliseconds: elapsedMs),
        segmentCount: segments,
        freeBytes: freeBytes,
        isPowerSaveMode: powerSave,
        isForceMode: isForce,
        markers: markers,
        statusMessage: nextMessage,
        messageLevel: level,
      );
      return;
    }

    if (event == 'open_record') {
      state = state.copyWith(
        openRecordRequestSeq: state.openRecordRequestSeq + 1,
      );
      return;
    }

    if (event == 'saved') {
      final rawRec = data['recording'];
      final msg = data['message']?.toString() ?? 'Recording saved.';
      final level = data['messageLevel']?.toString() ?? 'info';
      final item = rawRec is Map
          ? RecordingItem.fromJson(Map<String, dynamic>.from(rawRec))
          : null;
      unawaited(
        _finalizeSavedEvent(
          item: item,
          msg: msg,
          level: level,
        ),
      );
    }
  }

  Future<void> _finalizeSavedEvent({
    required RecordingItem? item,
    required String msg,
    required String level,
  }) async {
    if (item != null) {
      await ref.read(meetingRepositoryProvider).saveRecordedMeeting(item);
      await ref.read(meetingsProvider.notifier).refresh();
    }
    _waveform.reset();
    state = state.copyWith(
      status: RecorderStatus.idle,
      elapsed: Duration.zero,
      segmentCount: 0,
      markers: const [],
      statusMessage: msg,
      messageLevel: level,
      lastSavedMeetingId: item?.id,
    );
    unawaited(refreshDeviceStatus());
  }
}
