import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:material_ui/material_ui.dart';

import '../models/recording_item.dart';
import '../services/native_bridge.dart';
import '../services/permissions_service.dart';
import '../services/playback_controller.dart';
import '../services/recording_storage.dart';
import '../services/recording_task_handler.dart';

enum _RecorderUiState { idle, recording, paused, finalizing }

class SpikeHomeScreen extends StatefulWidget {
  const SpikeHomeScreen({super.key});

  @override
  State<SpikeHomeScreen> createState() => _SpikeHomeScreenState();
}

class _SpikeHomeScreenState extends State<SpikeHomeScreen>
    with WidgetsBindingObserver {
  final PlaybackController _playback = PlaybackController();

  _RecorderUiState _recorderState = _RecorderUiState.idle;
  Duration _elapsed = Duration.zero;
  int _segmentCount = 0;
  int _freeBytes = 0;
  bool _isPowerSaveMode = false;
  bool _isBusy = false;
  bool _forceMode = false;
  bool _activeSessionForceMode = false;

  String? _statusMessage;
  String _messageLevel = 'info';

  List<RecordingItem> _recordings = const [];
  bool _loadingRecordings = true;

  OemDeviceInfo? _oemInfo;
  bool _ignoringBatteryOpt = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    _playback.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshDeviceStatus());
      unawaited(_syncWithRunningService());
    }
  }

  Future<void> _bootstrap() async {
    try {
      await _playback.init();
      final savedForce = await RecordingStorage.getForceMode();
      if (mounted) {
        setState(() => _forceMode = savedForce);
      }
      await _refreshDeviceStatus();

      final isRunning = await FlutterForegroundTask.isRunningService;
      if (isRunning) {
        _recorderState = _RecorderUiState.recording;
        _activeSessionForceMode = savedForce;
        FlutterForegroundTask.sendDataToTask({'cmd': 'ping'});
      } else {
        final recovered = await RecordingStorage.recoverPendingSessions();
        if (recovered.isNotEmpty) {
          _statusMessage =
              'Recovered ${recovered.length} interrupted recording(s) from saved segments.';
          _messageLevel = 'warning';
        }
      }

      await _loadRecordings();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingRecordings = false;
          _statusMessage ??= 'Startup check warning: $e';
          _messageLevel = 'warning';
        });
      }
    } finally {
      if (mounted && _loadingRecordings) {
        setState(() => _loadingRecordings = false);
      }
    }
  }

  Future<void> _refreshDeviceStatus() async {
    try {
      final oem = await PermissionsService.getOemDeviceInfo();
      final ignoringBattery =
          await PermissionsService.isIgnoringBatteryOptimizations();
      final dir = await RecordingStorage.getRecordingsDirectory();
      final freeBytes = await NativeBridge.getAvailableStorageBytes(dir.path);
      final env = await NativeBridge.getAudioEnvironmentState();

      if (!mounted) return;
      setState(() {
        _oemInfo = oem;
        _ignoringBatteryOpt = ignoringBattery;
        _freeBytes = freeBytes;
        _isPowerSaveMode = env.isPowerSaveMode;
      });
    } catch (_) {
      // Keep UI usable even if a platform telemetry query fails.
    }
  }

  Future<void> _syncWithRunningService() async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (!mounted) return;
    if (isRunning) {
      FlutterForegroundTask.sendDataToTask({'cmd': 'ping'});
    } else if (_recorderState != _RecorderUiState.idle) {
      setState(() {
        _recorderState = _RecorderUiState.idle;
      });
      await _loadRecordings();
    }
  }

  Future<void> _loadRecordings() async {
    final items = await RecordingStorage.listRecordings();
    if (!mounted) return;
    setState(() {
      _recordings = items;
      _loadingRecordings = false;
    });
  }

  void _onTaskData(Object data) {
    if (data is! Map || !mounted) return;
    final event = data['event']?.toString();

    if (event == 'status') {
      final stateStr = data['state']?.toString() ?? 'idle';
      final elapsedMs = (data['elapsedMs'] as num?)?.toInt() ?? 0;
      final segments = (data['segmentCount'] as num?)?.toInt() ?? 0;
      final freeBytes = (data['freeBytes'] as num?)?.toInt() ?? _freeBytes;
      final powerSave = data['isPowerSaveMode'] as bool? ?? _isPowerSaveMode;
      final isForce = data['isForceMode'] as bool? ?? _activeSessionForceMode;
      final msg = data['message']?.toString();
      final level = data['messageLevel']?.toString() ?? 'info';

      setState(() {
        _elapsed = Duration(milliseconds: elapsedMs);
        _segmentCount = segments;
        _freeBytes = freeBytes;
        _isPowerSaveMode = powerSave;
        _activeSessionForceMode = isForce;
        if (msg != null && msg.isNotEmpty) {
          _statusMessage = msg;
          _messageLevel = level;
        }
        _recorderState = switch (stateStr) {
          'recording' => _RecorderUiState.recording,
          'paused' => _RecorderUiState.paused,
          'finalizing' => _RecorderUiState.finalizing,
          _ => _RecorderUiState.idle,
        };
      });
    } else if (event == 'saved') {
      final msg = data['message']?.toString() ?? 'Recording saved.';
      final level = data['messageLevel']?.toString() ?? 'info';
      setState(() {
        _recorderState = _RecorderUiState.idle;
        _elapsed = Duration.zero;
        _segmentCount = 0;
        _activeSessionForceMode = false;
        _statusMessage = msg;
        _messageLevel = level;
      });
      unawaited(_loadRecordings());
      unawaited(_refreshDeviceStatus());
    }
  }

  Future<void> _toggleForceMode(bool value) async {
    setState(() => _forceMode = value);
    try {
      await RecordingStorage.setForceMode(value);
    } catch (_) {}
  }

  Future<void> _startRecording() async {
    if (_isBusy || _recorderState != _RecorderUiState.idle) return;
    setState(() => _isBusy = true);

    try {
      if (_playback.isPlaying) {
        await _playback.stop();
      }
      if (!mounted) return;

      final granted =
          await PermissionsService.ensureRecordingPermissions(context);
      if (!granted || !mounted) return;

      if (_oemInfo?.needsAggressiveBackgroundHelp == true &&
          !_ignoringBatteryOpt) {
        await PermissionsService.requestBatteryOptimizationExemption(context);
        await _refreshDeviceStatus();
        if (!mounted) return;
      }

      final dir = await RecordingStorage.getRecordingsDirectory();
      final freeBytes = await NativeBridge.getAvailableStorageBytes(dir.path);
      if (freeBytes > 0 && freeBytes < 20 * 1024 * 1024) {
        setState(() {
          _freeBytes = freeBytes;
          _statusMessage =
              'Not enough free storage (< 20 MB). Free up space before recording.';
          _messageLevel = 'error';
        });
        return;
      }

      final now = DateTime.now();
      final title =
          'Spike ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await FlutterForegroundTask.saveData(
        key: 'pending_title',
        value: title,
      );
      await FlutterForegroundTask.saveData(
        key: 'pending_force_mode',
        value: _forceMode,
      );

      final result = await FlutterForegroundTask.startService(
        serviceId: 1001,
        serviceTypes: [ForegroundServiceTypes.microphone],
        notificationTitle:
            _forceMode ? 'Minute • FORCE Recording' : 'Minute • Recording',
        notificationText: _forceMode
            ? 'FORCE • 00:00 • Starting 16 kHz AAC capture...'
            : '00:00 • Starting 16 kHz AAC capture...',
        notificationButtons: const [
          NotificationButton(id: 'stop', text: 'Stop'),
        ],
        callback: startRecordingTaskCallback,
      );

      if (!mounted) return;
      if (result is ServiceRequestSuccess) {
        setState(() {
          _recorderState = _RecorderUiState.recording;
          _activeSessionForceMode = _forceMode;
          _elapsed = Duration.zero;
          _segmentCount = 1;
          _statusMessage = _forceMode
              ? 'FORCE recording started (never auto-pauses).'
              : 'Foreground recording started.';
          _messageLevel = 'info';
        });
      } else if (result is ServiceRequestFailure) {
        setState(() {
          _statusMessage = 'Failed to start foreground service: ${result.error}';
          _messageLevel = 'error';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  void _pauseOrResumeRecording() {
    if (_recorderState == _RecorderUiState.recording) {
      FlutterForegroundTask.sendDataToTask({'cmd': 'pause'});
    } else if (_recorderState == _RecorderUiState.paused) {
      FlutterForegroundTask.sendDataToTask({'cmd': 'resume'});
    }
  }

  void _stopRecording() {
    if (_recorderState == _RecorderUiState.idle ||
        _recorderState == _RecorderUiState.finalizing) {
      return;
    }
    setState(() {
      _recorderState = _RecorderUiState.finalizing;
      _statusMessage = 'Stopping and merging segments...';
      _messageLevel = 'info';
    });
    FlutterForegroundTask.sendDataToTask({'cmd': 'stop'});
  }

  Future<void> _deleteRecording(RecordingItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete recording?'),
        content: Text('Delete "${item.title}" permanently from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _playback.stopIfCurrent(item);
    await RecordingStorage.deleteRecording(item);
    await _loadRecordings();
    await _refreshDeviceStatus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final oem = _oemInfo;

    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Minute • Phase 0 Spike'),
          actions: [
            if (oem != null)
              IconButton(
                tooltip: 'Background & autostart help',
                icon: const Icon(Icons.battery_saver_outlined),
                onPressed: () =>
                    PermissionsService.openAutoStartHelpDialog(context, oem),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (oem != null &&
                (oem.needsAggressiveBackgroundHelp && !_ignoringBatteryOpt ||
                    _isPowerSaveMode))
              _OemWarningCard(
                oem: oem,
                ignoringBatteryOpt: _ignoringBatteryOpt,
                isPowerSaveMode: _isPowerSaveMode,
                onExcludeBattery: () async {
                  await PermissionsService.requestBatteryOptimizationExemption(
                    context,
                  );
                  await _refreshDeviceStatus();
                },
                onOpenAutostartHelp: () =>
                    PermissionsService.openAutoStartHelpDialog(context, oem),
              ),
            if (_statusMessage != null) ...[
              _StatusBanner(
                message: _statusMessage!,
                level: _messageLevel,
                onDismiss: _recorderState == _RecorderUiState.idle
                    ? () => setState(() => _statusMessage = null)
                    : null,
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _StatePill(state: _recorderState),
                            if (_recorderState != _RecorderUiState.idle &&
                                _activeSessionForceMode)
                              const _ForceChip(),
                          ],
                        ),
                        Text(
                          _freeBytes > 0
                              ? 'Free: ${_formatBytes(_freeBytes)}'
                              : 'Free: checking...',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatDuration(_elapsed),
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        _recorderState == _RecorderUiState.idle
                            ? 'AAC / .m4a • 16 kHz mono • 30s disk segments'
                            : 'Segment #$_segmentCount saved on disk • 16 kHz mono AAC',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_recorderState == _RecorderUiState.idle) ...[
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 52),
                        child: FilledButton.icon(
                          onPressed: _isBusy ? null : _startRecording,
                          icon: const Icon(Icons.mic),
                          label: const Text('Start Recording'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Force record (never pause)'),
                        subtitle: const Text(
                          'Ignores audio focus loss, calls, and headset unplugs. Marks silence > 5s.',
                        ),
                        value: _forceMode,
                        onChanged: _isBusy ? null : _toggleForceMode,
                      ),
                    ] else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 52),
                            child: OutlinedButton.icon(
                              onPressed:
                                  _recorderState == _RecorderUiState.finalizing
                                      ? null
                                      : _pauseOrResumeRecording,
                              icon: Icon(
                                _recorderState == _RecorderUiState.paused
                                    ? Icons.play_arrow
                                    : Icons.pause,
                              ),
                              label: Text(
                                _recorderState == _RecorderUiState.paused
                                    ? 'Resume'
                                    : 'Pause',
                              ),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 52),
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.error,
                                foregroundColor: colorScheme.onError,
                              ),
                              onPressed:
                                  _recorderState == _RecorderUiState.finalizing
                                      ? null
                                      : _stopRecording,
                              icon: const Icon(Icons.stop),
                              label: Text(
                                _recorderState == _RecorderUiState.finalizing
                                    ? 'Saving...'
                                    : 'Stop & Save',
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Saved Recordings (${_recordings.length})',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh list',
                  onPressed: _loadRecordings,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingRecordings)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_recordings.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No saved recordings yet. Tap "Start Recording" above to run your Phase 0 test.',
                  ),
                ),
              )
            else
              ListenableBuilder(
                listenable: _playback,
                builder: (context, _) {
                  return Column(
                    children: [
                      if (_playback.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _StatusBanner(
                            message: _playback.errorMessage!,
                            level: 'error',
                          ),
                        ),
                      for (final item in _recordings)
                        _RecordingCard(
                          item: item,
                          isCurrent: _playback.currentItem?.id == item.id,
                          isPlaying: _playback.currentItem?.id == item.id &&
                              _playback.isPlaying,
                          isLoading: _playback.currentItem?.id == item.id &&
                              _playback.isLoading,
                          position: _playback.currentItem?.id == item.id
                              ? _playback.position
                              : Duration.zero,
                          totalDuration: _playback.currentItem?.id == item.id &&
                                  _playback.duration > Duration.zero
                              ? _playback.duration
                              : item.duration,
                          onTogglePlay: () => _playback.togglePlay(item),
                          onSeek: _playback.seek,
                          onDelete: () => _deleteRecording(item),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}

class _OemWarningCard extends StatelessWidget {
  const _OemWarningCard({
    required this.oem,
    required this.ignoringBatteryOpt,
    required this.isPowerSaveMode,
    required this.onExcludeBattery,
    required this.onOpenAutostartHelp,
  });

  final OemDeviceInfo oem;
  final bool ignoringBatteryOpt;
  final bool isPowerSaveMode;
  final VoidCallback onExcludeBattery;
  final VoidCallback onOpenAutostartHelp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${oem.brand} (${oem.model}) Background Recording Check',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isPowerSaveMode
                  ? 'Battery Saver is ON. Disable Battery Saver or exclude Minute so 30+ minute screen-off recordings are not throttled.'
                  : 'For reliable 30+ minute recordings with the screen locked, exclude Minute from battery optimization and enable background autostart.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!ignoringBatteryOpt)
                  FilledButton(
                    onPressed: onExcludeBattery,
                    child: const Text('Exclude Battery Opt.'),
                  ),
                OutlinedButton(
                  onPressed: onOpenAutostartHelp,
                  child: const Text('Autostart Help'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.level,
    this.onDismiss,
  });

  final String message;
  final String level;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color bg;
    final Color fg;
    final IconData icon;

    switch (level) {
      case 'error':
        bg = scheme.errorContainer;
        fg = scheme.onErrorContainer;
        icon = Icons.error_outline;
        break;
      case 'warning':
        bg = scheme.tertiaryContainer;
        fg = scheme.onTertiaryContainer;
        icon = Icons.warning_amber_outlined;
        break;
      default:
        bg = scheme.surfaceContainerHighest;
        fg = scheme.onSurface;
        icon = Icons.info_outline;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: TextStyle(color: fg)),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: Icon(Icons.close, color: fg),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.state});

  final _RecorderUiState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (String label, Color bg, Color fg) = switch (state) {
      _RecorderUiState.idle => ('Ready', scheme.surfaceContainerHigh, scheme.onSurface),
      _RecorderUiState.recording => ('Recording', scheme.errorContainer, scheme.onErrorContainer),
      _RecorderUiState.paused => ('Paused', scheme.tertiaryContainer, scheme.onTertiaryContainer),
      _RecorderUiState.finalizing => ('Saving', scheme.primaryContainer, scheme.onPrimaryContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ForceChip extends StatelessWidget {
  const _ForceChip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'FORCE',
        style: TextStyle(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({
    required this.item,
    required this.isCurrent,
    required this.isPlaying,
    required this.isLoading,
    required this.position,
    required this.totalDuration,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onDelete,
  });

  final RecordingItem item;
  final bool isCurrent;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration totalDuration;
  final VoidCallback onTogglePlay;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMs = totalDuration.inMilliseconds > 0
        ? totalDuration.inMilliseconds
        : 1;
    final posMs = position.inMilliseconds.clamp(0, totalMs);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: isPlaying ? 'Pause' : 'Play',
                  onPressed: isLoading ? null : onTogglePlay,
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            item.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (item.isForceMode)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'FORCE',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatShortDuration(totalDuration)} • '
                        '${_formatBytes(item.sizeBytes)} • '
                        '${item.segmentCount} seg(s)',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete recording',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (item.silenceMarkers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final marker in item.silenceMarkers)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        marker.displayLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (item.note != null && item.note!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (isCurrent) ...[
              const SizedBox(height: 6),
              Slider(
                value: posMs.toDouble(),
                max: totalMs.toDouble(),
                onChanged: (v) => onSeek(Duration(milliseconds: v.round())),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatShortDuration(position),
                    style: theme.textTheme.labelSmall,
                  ),
                  Text(
                    _formatShortDuration(totalDuration),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatShortDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}
