import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart' as p;

import '../data/database/app_database.dart';
import '../models/recording_item.dart';
import 'app_settings.dart';
import 'backend_api_client.dart';
import 'secure_token_storage.dart';

typedef ConnectivityChecker = Future<List<ConnectivityResult>> Function();
typedef ConnectivityStreamFactory = Stream<List<ConnectivityResult>> Function();
typedef DelayFn = Future<void> Function(Duration duration);
typedef ReadyNotificationFn = Future<bool> Function({
  required String meetingId,
  required String title,
});

/// Handles chunked resumable uploads, connectivity pauses (Wi-Fi only / offline),
/// retry backoff, and DB queue state (`UploadQueue`).
class UploadManager {
  UploadManager({
    required this._db,
    required this._api,
    required this._tokenStorage,
    required this._loadSettings,
    ConnectivityChecker? checkConnectivity,
    ConnectivityStreamFactory? connectivityStream,
    DelayFn? delayFn,
    this._onStateChanged,
    this._onUploadComplete,
    this._chunkSizeBytes = defaultChunkSizeBytes,
  })  : _checkConnectivity =
            checkConnectivity ?? (() => Connectivity().checkConnectivity()),
        _connectivityStream = connectivityStream ??
            (() => Connectivity().onConnectivityChanged),
        _delay = delayFn ?? Future<void>.delayed;

  static const int defaultChunkSizeBytes = 1024 * 1024; // 1 MB chunks
  static const int maxTransientRetries = 3;

  final AppDatabase _db;
  final BackendApiClient _api;
  final TokenStorage _tokenStorage;
  final Future<AppSettings> Function() _loadSettings;
  final ConnectivityChecker _checkConnectivity;
  final ConnectivityStreamFactory _connectivityStream;
  final DelayFn _delay;
  final void Function(String meetingId)? _onStateChanged;
  final void Function(String meetingId)? _onUploadComplete;
  final int _chunkSizeBytes;

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _processingQueue = false;
  bool _rerunRequested = false;
  bool _disposed = false;

  Future<void> startListening() async {
    if (_disposed || _connSub != null) return;
    try {
      // Probe channel first so headless tests without connectivity_plus registered
      // do not trigger unhandled EventChannel errors on receiveBroadcastStream().
      await _checkConnectivity();
      if (_disposed || _connSub != null) return;
      _connSub = _connectivityStream().listen(
        (results) {
          if (!_disposed && !results.contains(ConnectivityResult.none)) {
            unawaited(processPendingUploads());
          }
        },
        onError: (_) {},
      );
    } catch (_) {
      // Safe fallback in headless tests without platform connectivity streams.
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(_connSub?.cancel() ?? Future<void>.value());
    _connSub = null;
  }

  static bool isNetworkPermitted(
    List<ConnectivityResult> results, {
    required bool wifiOnly,
  }) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return false;
    }
    if (!wifiOnly) {
      return results.any((r) => r != ConnectivityResult.none);
    }
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
  }

  static String? networkPauseReason(
    List<ConnectivityResult> results, {
    required bool wifiOnly,
  }) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return 'Offline — upload paused and will resume automatically.';
    }
    if (wifiOnly &&
        !results.contains(ConnectivityResult.wifi) &&
        !results.contains(ConnectivityResult.ethernet)) {
      return 'Waiting for Wi-Fi (Wi-Fi only enabled).';
    }
    return null;
  }

  Future<void> enqueueAndProcess(String meetingId) async {
    final detail = await _db.getMeetingDetail(meetingId);
    if (detail == null) return;
    final m = detail.meeting;
    final path = m.audioPath;
    if (path == null || path.isEmpty) {
      await _db.updateMeetingServerState(
        meetingId,
        status: 'Failed',
        statusMessage: 'Audio file is missing from this phone.',
      );
      _onStateChanged?.call(meetingId);
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      await _db.updateMeetingServerState(
        meetingId,
        status: 'Failed',
        statusMessage: 'Audio file could not be found on disk.',
      );
      _onStateChanged?.call(meetingId);
      return;
    }

    final totalBytes = file.lengthSync();
    if (totalBytes <= 0) {
      await _db.updateMeetingServerState(
        meetingId,
        status: 'Failed',
        statusMessage: 'Recorded audio file is empty.',
      );
      _onStateChanged?.call(meetingId);
      return;
    }

    final existing = await _db.getUploadEntryForMeeting(meetingId);
    final preservedUploaded = (existing != null &&
            existing.totalBytes == totalBytes &&
            existing.uploadedBytes > 0 &&
            existing.uploadedBytes <= totalBytes)
        ? existing.uploadedBytes
        : 0;

    await _db.upsertUploadQueueEntry(
      meetingId: meetingId,
      filePath: path,
      totalBytes: totalBytes,
      uploadedBytes: preservedUploaded,
      status: 'pending',
      lastError: null,
      attempts: existing?.attempts ?? 0,
    );
    final pct = totalBytes > 0
        ? ((preservedUploaded * 100) ~/ totalBytes).clamp(0, 99)
        : 0;
    await _db.updateMeetingServerState(
      meetingId,
      status: 'Uploading',
      uploadProgress: pct,
      statusMessage: preservedUploaded > 0
          ? 'Resuming upload ($pct%)...'
          : 'Queued for upload...',
    );
    _onStateChanged?.call(meetingId);

    await processPendingUploads();
  }

  Future<void> processPendingUploads() async {
    if (_disposed) return;
    if (_processingQueue) {
      _rerunRequested = true;
      return;
    }
    _processingQueue = true;
    try {
      do {
        _rerunRequested = false;
        final pending = await _db.listPendingUploads();
        for (final entry in pending) {
          if (_disposed) break;
          await uploadSingleMeeting(entry.meetingId);
        }
      } while (_rerunRequested && !_disposed);
    } finally {
      _processingQueue = false;
    }
  }

  Future<bool> uploadSingleMeeting(String meetingId) async {
    final detail = await _db.getMeetingDetail(meetingId);
    final entry = await _db.getUploadEntryForMeeting(meetingId);
    if (detail == null || entry == null || entry.status == 'completed') {
      return false;
    }

    final settings = await _loadSettings();
    final serverUrl = AppSettings.normalizeServerUrl(settings.serverUrl);
    if (!settings.hasConsentedFor(serverUrl)) {
      await _db.updateUploadProgress(
        meetingId: meetingId,
        uploadedBytes: entry.uploadedBytes,
        totalBytes: entry.totalBytes,
        status: 'paused',
        lastError: 'Upload consent required for $serverUrl.',
      );
      await _db.updateMeetingServerState(
        meetingId,
        status: 'Recorded',
        statusMessage: 'Consent required before uploading to $serverUrl.',
      );
      _onStateChanged?.call(meetingId);
      return false;
    }

    final conn = await _checkConnectivity();
    final pauseMsg = networkPauseReason(conn, wifiOnly: settings.wifiOnlyUpload);
    if (pauseMsg != null) {
      final pct = entry.totalBytes > 0
          ? ((entry.uploadedBytes * 100) ~/ entry.totalBytes).clamp(0, 99)
          : 0;
      await _db.updateUploadProgress(
        meetingId: meetingId,
        uploadedBytes: entry.uploadedBytes,
        totalBytes: entry.totalBytes,
        status: 'paused',
        lastError: pauseMsg,
      );
      await _db.updateMeetingServerState(
        meetingId,
        status: 'Uploading',
        uploadProgress: pct,
        statusMessage: pauseMsg,
      );
      _onStateChanged?.call(meetingId);
      return false;
    }

    final token = await _tokenStorage.readToken();
    final file = File(entry.filePath);
    if (!file.existsSync()) {
      const msg = 'Audio file is no longer on device.';
      await _markFailed(meetingId, entry.uploadedBytes, entry.totalBytes, msg, entry.attempts);
      return false;
    }

    final totalBytes = file.lengthSync();
    var attempts = entry.attempts;

    while (!_disposed) {
      try {
        final currentMeeting = await _db.getMeetingById(meetingId);
        if (currentMeeting == null) return false;

        final ext = p
            .extension(entry.filePath)
            .replaceFirst('.', '')
            .trim()
            .toLowerCase();
        final safeExt = ext.isEmpty ? 'm4a' : ext;

        var serverId = currentMeeting.serverMeetingId;
        if (serverId == null || serverId.isEmpty) {
          serverId = await _api.createOrGetMeeting(
            serverUrl: serverUrl,
            token: token,
            clientMeetingId: currentMeeting.id,
            title: currentMeeting.title,
            languageHint: currentMeeting.language,
            glossary: currentMeeting.glossary?.isNotEmpty == true
                ? currentMeeting.glossary
                : settings.defaultGlossary,
            durationSec: currentMeeting.durationMs / 1000.0,
            totalBytes: totalBytes,
            fileExt: safeExt,
          );
          await _db.updateMeetingServerState(
            meetingId,
            serverMeetingId: serverId,
          );
        }

        // Always query server offset when resuming an existing upload or retrying.
        var offset = entry.uploadedBytes;
        if (offset > 0 || attempts > 0 || serverId.isNotEmpty) {
          final serverState = await _api.getUploadOffset(
            serverUrl: serverUrl,
            token: token,
            serverMeetingId: serverId,
          );
          offset = serverState.receivedBytes.clamp(0, totalBytes);
          if (serverState.status == 'completed' || offset >= totalBytes) {
            await _finishUpload(meetingId, totalBytes, serverId, detail, currentMeeting);
            return true;
          }
        }

        await _db.updateUploadProgress(
          meetingId: meetingId,
          uploadedBytes: offset,
          totalBytes: totalBytes,
          status: 'uploading',
          clearError: true,
        );

        final raf = await file.open(mode: FileMode.read);
        try {
          while (offset < totalBytes && !_disposed) {
            final liveConn = await _checkConnectivity();
            final livePause = networkPauseReason(
              liveConn,
              wifiOnly: settings.wifiOnlyUpload,
            );
            if (livePause != null) {
              final pct = ((offset * 100) ~/ totalBytes).clamp(0, 99);
              await _db.updateUploadProgress(
                meetingId: meetingId,
                uploadedBytes: offset,
                totalBytes: totalBytes,
                status: 'paused',
                lastError: livePause,
              );
              await _db.updateMeetingServerState(
                meetingId,
                status: 'Uploading',
                uploadProgress: pct,
                statusMessage: livePause,
              );
              _onStateChanged?.call(meetingId);
              return false;
            }

            final nextEnd = (offset + _chunkSizeBytes) < totalBytes
                ? (offset + _chunkSizeBytes)
                : totalBytes;
            final len = nextEnd - offset;
            await raf.setPosition(offset);
            final chunk = Uint8List.fromList(await raf.read(len));

            try {
              final ack = await _api.uploadChunk(
                serverUrl: serverUrl,
                token: token,
                serverMeetingId: serverId,
                startByte: offset,
                endByteInclusive: nextEnd - 1,
                totalBytes: totalBytes,
                fileExt: safeExt,
                bytes: chunk,
              );
              offset = ack.receivedBytes.clamp(0, totalBytes);
              final pct = ((offset * 100) ~/ totalBytes).clamp(0, 100);
              await _db.updateUploadProgress(
                meetingId: meetingId,
                uploadedBytes: offset,
                totalBytes: totalBytes,
                status: ack.complete ? 'completed' : 'uploading',
                clearError: true,
              );
              await _db.updateMeetingServerState(
                meetingId,
                status: ack.complete ? 'Queued' : 'Uploading',
                uploadProgress: pct,
                statusMessage: ack.complete
                    ? 'Uploaded. Queued on server...'
                    : 'Uploading audio ($pct%)...',
              );
              _onStateChanged?.call(meetingId);

              if (ack.complete || offset >= totalBytes) {
                await _finishUpload(
                  meetingId,
                  totalBytes,
                  serverId,
                  detail,
                  currentMeeting,
                );
                return true;
              }
            } on BackendException catch (e) {
              if (e.kind == BackendFailureKind.uploadInterrupted &&
                  e.expectedOffset != null) {
                offset = e.expectedOffset!.clamp(0, totalBytes);
                await _db.updateUploadProgress(
                  meetingId: meetingId,
                  uploadedBytes: offset,
                  totalBytes: totalBytes,
                  status: 'uploading',
                );
                continue;
              }
              rethrow;
            }
          }
        } finally {
          await raf.close();
        }
        return false;
      } on BackendException catch (e) {
        final isTransient = e.kind == BackendFailureKind.uploadInterrupted ||
            e.kind == BackendFailureKind.serverUnreachable ||
            e.kind == BackendFailureKind.rateLimited;
        attempts += 1;

        final latestEntry = await _db.getUploadEntryForMeeting(meetingId);
        final savedOffset = latestEntry?.uploadedBytes ?? entry.uploadedBytes;

        if (!isTransient || attempts >= maxTransientRetries) {
          await _markFailed(
            meetingId,
            savedOffset,
            totalBytes,
            e.userMessage,
            attempts,
          );
          return false;
        }

        final backoffSec = 1 << (attempts - 1);
        final pct = totalBytes > 0
            ? ((savedOffset * 100) ~/ totalBytes).clamp(0, 99)
            : 0;
        await _db.updateUploadProgress(
          meetingId: meetingId,
          uploadedBytes: savedOffset,
          totalBytes: totalBytes,
          status: 'paused',
          lastError: e.userMessage,
          attempts: attempts,
        );
        await _db.updateMeetingServerState(
          meetingId,
          status: 'Uploading',
          uploadProgress: pct,
          statusMessage: '${e.userMessage} Retrying in ${backoffSec}s...',
        );
        _onStateChanged?.call(meetingId);
        await _delay(Duration(seconds: backoffSec));
      }
    }
    return false;
  }

  Future<void> _finishUpload(
    String meetingId,
    int totalBytes,
    String serverId,
    MeetingDetailData initialDetail,
    Meeting currentMeeting,
  ) async {
    await _db.updateUploadProgress(
      meetingId: meetingId,
      uploadedBytes: totalBytes,
      totalBytes: totalBytes,
      status: 'completed',
      clearError: true,
    );

    final silenceHints = initialDetail.markers
        .where((m) => m.type == MarkerType.silence && m.endMs != null)
        .map((m) => (startSec: m.startMs / 1000.0, endSec: m.endMs! / 1000.0))
        .toList();

    final settings = await _loadSettings();
    final token = await _tokenStorage.readToken();
    try {
      final statusRes = await _api.triggerProcess(
        serverUrl: settings.serverUrl,
        token: token,
        serverMeetingId: serverId,
        languageHint: currentMeeting.language,
        glossary: currentMeeting.glossary?.isNotEmpty == true
            ? currentMeeting.glossary
            : settings.defaultGlossary,
        silenceRanges: silenceHints.isEmpty ? null : silenceHints,
      );
      await _db.updateMeetingServerState(
        meetingId,
        status: _mapServerStatusToUi(statusRes.status),
        uploadProgress: 100,
        statusMessage: statusRes.message.isNotEmpty
            ? statusRes.message
            : 'Queued for transcription.',
      );
    } catch (_) {
      // Upload already auto-starts transcription on server; fallback safely to Queued.
      await _db.updateMeetingServerState(
        meetingId,
        status: 'Queued',
        uploadProgress: 100,
        statusMessage: 'Upload complete. Queued on server...',
      );
    }
    _onStateChanged?.call(meetingId);
    _onUploadComplete?.call(meetingId);
  }

  Future<void> _markFailed(
    String meetingId,
    int uploadedBytes,
    int totalBytes,
    String message,
    int attempts,
  ) async {
    await _db.updateUploadProgress(
      meetingId: meetingId,
      uploadedBytes: uploadedBytes,
      totalBytes: totalBytes,
      status: 'failed',
      lastError: message,
      attempts: attempts,
    );
    await _db.updateMeetingServerState(
      meetingId,
      status: 'Failed',
      statusMessage: message,
    );
    _onStateChanged?.call(meetingId);
  }

  static String _mapServerStatusToUi(String serverStatus) {
    return switch (serverStatus.toLowerCase()) {
      'ready' => 'Ready',
      'transcribing' => 'Transcribing',
      'failed' => 'Failed',
      _ => 'Queued',
    };
  }
}
