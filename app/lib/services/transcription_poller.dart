import 'dart:async';

import '../data/database/app_database.dart';
import 'backend_api_client.dart';
import 'secure_token_storage.dart';
import 'upload_manager.dart';

/// Polls `/api/meetings/{id}/status` with backoff while a meeting is processing,
/// saving fetched segments to Drift on `ready` and halting on `ready`, `failed`,
/// or `dispose()`.
class MeetingStatusPoller {
  MeetingStatusPoller({
    required this._db,
    required this._api,
    required this._tokenStorage,
    required this._loadServerUrl,
    this._notifyReady,
    DelayFn? delayFn,
    this._onUpdated,
  }) : _delay = delayFn ?? Future<void>.delayed;

  static const List<Duration> defaultBackoffSchedule = [
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 8),
    Duration(seconds: 10),
  ];

  final AppDatabase _db;
  final BackendApiClient _api;
  final TokenStorage _tokenStorage;
  final Future<String> Function() _loadServerUrl;
  final ReadyNotificationFn? _notifyReady;
  final DelayFn _delay;
  final void Function()? _onUpdated;

  bool _disposed = false;
  bool _running = false;
  String? _activeMeetingId;

  bool get isDisposed => _disposed;
  bool get isRunning => _running;

  /// Starts polling [localMeetingId] until terminal status or [dispose()].
  Future<void> pollUntilTerminal(
    String localMeetingId, {
    List<Duration>? backoffSchedule,
  }) async {
    if (_disposed) return;
    if (_running && _activeMeetingId == localMeetingId) return;

    _activeMeetingId = localMeetingId;
    _running = true;
    final schedule = backoffSchedule ?? defaultBackoffSchedule;
    var step = 0;

    try {
      while (!_disposed && _activeMeetingId == localMeetingId) {
        final meeting = await _db.getMeetingById(localMeetingId);
        if (meeting == null) break;
        final serverId = meeting.serverMeetingId;
        if (serverId == null || serverId.isEmpty) break;
        if (meeting.status == 'Ready' || meeting.status == 'Failed') break;
        if (meeting.status != 'Queued' && meeting.status != 'Transcribing') {
          break;
        }

        try {
          final url = await _loadServerUrl();
          final token = await _tokenStorage.readToken();
          final res = await _api.getStatus(
            serverUrl: url,
            token: token,
            serverMeetingId: serverId,
          );
          if (_disposed || _activeMeetingId != localMeetingId) break;

          final lower = res.status.toLowerCase();
          if (lower == 'ready') {
            final full = await _api.getMeeting(
              serverUrl: url,
              token: token,
              serverMeetingId: serverId,
              localMeetingId: localMeetingId,
            );
            if (_disposed) break;
            await _db.replaceMeetingTranscript(
              meetingId: localMeetingId,
              segmentDrafts: full.segments,
              detectedLanguage: full.detectedLanguage,
            );
            _onUpdated?.call();
            if (_notifyReady != null) {
              await _notifyReady(
                meetingId: localMeetingId,
                title: meeting.title,
              );
            }
            break;
          }

          if (lower == 'failed') {
            final errText = (res.errorMessage != null &&
                    res.errorMessage!.trim().isNotEmpty)
                ? res.errorMessage!.trim()
                : (res.message.trim().isNotEmpty
                    ? res.message.trim()
                    : 'Transcription failed on server.');
            await _db.updateMeetingServerState(
              localMeetingId,
              status: 'Failed',
              statusMessage: errText,
            );
            _onUpdated?.call();
            break;
          }

          final nextStatus = lower == 'transcribing' ? 'Transcribing' : 'Queued';
          final pct = res.progressPercent.clamp(0, 99);
          final msg = res.message.isNotEmpty
              ? '$nextStatus ($pct%) • ${res.message}'
              : '$nextStatus ($pct%)';
          await _db.updateMeetingServerState(
            localMeetingId,
            status: nextStatus,
            statusMessage: msg,
          );
          _onUpdated?.call();
        } on BackendException catch (e) {
          if (_disposed) break;
          if (e.kind == BackendFailureKind.wrongToken) {
            await _db.updateMeetingServerState(
              localMeetingId,
              status: 'Failed',
              statusMessage: e.userMessage,
            );
            _onUpdated?.call();
            break;
          }
          await _db.updateMeetingServerState(
            localMeetingId,
            statusMessage: e.userMessage,
          );
          _onUpdated?.call();
        }

        if (_disposed || _activeMeetingId != localMeetingId) break;
        final waitDur =
            schedule[step < schedule.length ? step : schedule.length - 1];
        step++;
        await _delay(waitDur);
      }
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _disposed = true;
    _activeMeetingId = null;
  }
}
