import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../data/database/app_database.dart';
import 'app_settings.dart';

enum BackendFailureKind {
  serverUnreachable,
  wrongToken,
  fileTooLarge,
  uploadInterrupted,
  transcriptionFailed,
  cleartextBlocked,
  unsupportedAudio,
  rateLimited,
  invalidServerUrl,
  unexpected,
}

class BackendException implements Exception {
  const BackendException(this.kind, this.userMessage, {this.expectedOffset});

  final BackendFailureKind kind;
  final String userMessage;
  final int? expectedOffset;

  @override
  String toString() => 'BackendException($kind): $userMessage';
}

class BackendHealth {
  const BackendHealth({
    required this.status,
    required this.provider,
    required this.model,
    required this.computeType,
    required this.defaultLanguage,
  });

  final String status;
  final String provider;
  final String model;
  final String computeType;
  final String defaultLanguage;

  factory BackendHealth.fromJson(Map<String, dynamic> json) {
    return BackendHealth(
      status: json['status']?.toString() ?? 'ok',
      provider: json['provider']?.toString() ?? 'faster_whisper',
      model: json['model']?.toString() ?? 'medium',
      computeType: json['compute_type']?.toString() ?? 'int8',
      defaultLanguage: json['default_language']?.toString() ?? 'ms',
    );
  }
}

class BackendStatusResult {
  const BackendStatusResult({
    required this.meetingId,
    required this.status,
    required this.progressPercent,
    required this.message,
    this.errorMessage,
  });

  final String meetingId;
  final String status;
  final int progressPercent;
  final String message;
  final String? errorMessage;

  factory BackendStatusResult.fromJson(Map<String, dynamic> json) {
    return BackendStatusResult(
      meetingId: json['meeting_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'queued',
      progressPercent: (json['progress_percent'] as num?)?.toInt() ?? 0,
      message: json['message']?.toString() ?? '',
      errorMessage: json['error_message']?.toString(),
    );
  }
}

class BackendMeetingDetail {
  const BackendMeetingDetail({
    required this.id,
    required this.clientMeetingId,
    required this.status,
    required this.progressPercent,
    required this.statusMessage,
    this.detectedLanguage,
    this.durationSec,
    this.errorMessage,
    required this.segments,
  });

  final String id;
  final String clientMeetingId;
  final String status;
  final int progressPercent;
  final String statusMessage;
  final String? detectedLanguage;
  final double? durationSec;
  final String? errorMessage;
  final List<TranscriptSegmentDraft> segments;

  factory BackendMeetingDetail.fromJson(
    Map<String, dynamic> json, {
    required String localMeetingId,
  }) {
    final rawSegments = json['segments'] as List<dynamic>? ?? const [];
    final parsed = <TranscriptSegmentDraft>[];
    for (var i = 0; i < rawSegments.length; i++) {
      final item = rawSegments[i];
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      parsed.add(
        TranscriptSegmentDraft(
          id: 'seg_${localMeetingId}_${map['id'] ?? i}',
          speakerLabel: map['speaker_label']?.toString() ?? 'Speaker 1',
          startSec: (map['start_sec'] as num?)?.toDouble() ?? 0.0,
          endSec: (map['end_sec'] as num?)?.toDouble() ?? 0.0,
          textContent: map['text']?.toString() ?? '',
          avgLogprob: (map['avg_logprob'] as num?)?.toDouble(),
          noSpeechProb: (map['no_speech_prob'] as num?)?.toDouble(),
          isLoopFlagged: map['is_loop_flagged'] as bool? ?? false,
        ),
      );
    }

    return BackendMeetingDetail(
      id: json['id']?.toString() ?? '',
      clientMeetingId: json['client_meeting_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ready',
      progressPercent: (json['progress_percent'] as num?)?.toInt() ?? 0,
      statusMessage: json['status_message']?.toString() ?? '',
      detectedLanguage: json['detected_language']?.toString(),
      durationSec: (json['duration_sec'] as num?)?.toDouble(),
      errorMessage: json['error_message']?.toString(),
      segments: parsed,
    );
  }
}

class BackendApiClient {
  BackendApiClient({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final http.Client _client;

  static Uri _buildUri(String baseUrl, String path) {
    final clean = AppSettings.normalizeServerUrl(baseUrl);
    if (clean.isEmpty) {
      throw const BackendException(
        BackendFailureKind.invalidServerUrl,
        'Configure a server URL in Settings first.',
      );
    }
    final parsed = Uri.tryParse(clean);
    if (parsed == null ||
        !parsed.hasScheme ||
        (parsed.scheme != 'http' && parsed.scheme != 'https') ||
        parsed.host.isEmpty) {
      throw const BackendException(
        BackendFailureKind.invalidServerUrl,
        'Enter a valid http:// or https:// server URL.',
      );
    }
    return parsed.resolve(path.startsWith('/') ? path : '/$path');
  }

  static Map<String, String> _authHeaders(
    String? token, {
    Map<String, String>? extra,
  }) {
    final cleanToken = token?.trim() ?? '';
    if (cleanToken.isEmpty) {
      throw const BackendException(
        BackendFailureKind.wrongToken,
        'API token is missing. Set it in Settings.',
      );
    }
    return {
      'Authorization': 'Bearer $cleanToken',
      ...?extra,
    };
  }

  Future<BackendHealth> testHealth({
    required String serverUrl,
    required String? token,
  }) async {
    final uri = _buildUri(serverUrl, '/api/health');
    final resp = await _send(() => _client.get(uri, headers: _authHeaders(token)));
    _throwIfError(resp);
    return BackendHealth.fromJson(_decodeMap(resp.body));
  }

  Future<String> createOrGetMeeting({
    required String serverUrl,
    required String? token,
    required String clientMeetingId,
    required String title,
    required String languageHint,
    required String? glossary,
    required double? durationSec,
    required int totalBytes,
    required String fileExt,
  }) async {
    final uri = _buildUri(serverUrl, '/api/meetings');
    final body = jsonEncode({
      'client_meeting_id': clientMeetingId,
      'title': title,
      'language_hint': normalizeLanguageCode(languageHint),
      'glossary': glossary,
      'duration_sec': durationSec,
      'total_bytes': totalBytes,
      'file_ext': fileExt,
    });
    final resp = await _send(
      () => _client.post(
        uri,
        headers: _authHeaders(
          token,
          extra: {'Content-Type': 'application/json'},
        ),
        body: body,
      ),
    );
    _throwIfError(resp);
    final data = _decodeMap(resp.body);
    return data['id']?.toString() ?? '';
  }

  Future<({int receivedBytes, int totalBytes, String status})> getUploadOffset({
    required String serverUrl,
    required String? token,
    required String serverMeetingId,
  }) async {
    final uri = _buildUri(serverUrl, '/api/meetings/$serverMeetingId/upload');
    final resp = await _send(
      () => _client.head(uri, headers: _authHeaders(token)),
      isUpload: true,
    );
    if (resp.statusCode == 405) {
      final getResp = await _send(
        () => _client.get(uri, headers: _authHeaders(token)),
        isUpload: true,
      );
      _throwIfError(getResp, isUpload: true);
      final map = _decodeMap(getResp.body);
      return (
        receivedBytes: (map['received_bytes'] as num?)?.toInt() ?? 0,
        totalBytes: (map['total_bytes'] as num?)?.toInt() ?? 0,
        status: map['status']?.toString() ?? 'in_progress',
      );
    }
    _throwIfError(resp, isUpload: true);
    final offset = int.tryParse(resp.headers['upload-offset'] ?? '') ?? 0;
    final length = int.tryParse(resp.headers['upload-length'] ?? '') ?? 0;
    final status = resp.headers['x-upload-status'] ?? 'in_progress';
    return (receivedBytes: offset, totalBytes: length, status: status);
  }

  Future<({int receivedBytes, bool complete, String status})> uploadChunk({
    required String serverUrl,
    required String? token,
    required String serverMeetingId,
    required int startByte,
    required int endByteInclusive,
    required int totalBytes,
    required String fileExt,
    required Uint8List bytes,
  }) async {
    final uri = _buildUri(serverUrl, '/api/meetings/$serverMeetingId/upload');
    final resp = await _send(
      () => _client.put(
        uri,
        headers: _authHeaders(
          token,
          extra: {
            'Content-Range': 'bytes $startByte-$endByteInclusive/$totalBytes',
            'X-File-Extension': fileExt,
            'Content-Type': 'application/octet-stream',
          },
        ),
        body: bytes,
      ),
      isUpload: true,
      timeout: const Duration(seconds: 45),
    );

    if (resp.statusCode == 409) {
      final map = _tryDecodeMap(resp.body);
      final expected = (map?['expected_offset'] as num?)?.toInt();
      throw BackendException(
        BackendFailureKind.uploadInterrupted,
        'Upload offset changed on server. Resuming from server offset.',
        expectedOffset: expected,
      );
    }
    _throwIfError(resp, isUpload: true);
    final map = _decodeMap(resp.body);
    return (
      receivedBytes: (map['received_bytes'] as num?)?.toInt() ?? endByteInclusive + 1,
      complete: map['complete'] as bool? ?? false,
      status: map['status']?.toString() ?? 'uploading',
    );
  }

  Future<BackendStatusResult> triggerProcess({
    required String serverUrl,
    required String? token,
    required String serverMeetingId,
    String? languageHint,
    String? glossary,
    List<({double startSec, double endSec})>? silenceRanges,
  }) async {
    final uri = _buildUri(serverUrl, '/api/meetings/$serverMeetingId/process');
    final payload = <String, dynamic>{
      if (languageHint != null)
        'language_hint': normalizeLanguageCode(languageHint),
      'glossary': ?glossary,
      if (silenceRanges != null && silenceRanges.isNotEmpty)
        'silence_ranges': silenceRanges
            .map((r) => {'start_sec': r.startSec, 'end_sec': r.endSec})
            .toList(),
    };
    final resp = await _send(
      () => _client.post(
        uri,
        headers: _authHeaders(
          token,
          extra: {'Content-Type': 'application/json'},
        ),
        body: jsonEncode(payload),
      ),
    );
    _throwIfError(resp);
    return BackendStatusResult.fromJson(_decodeMap(resp.body));
  }

  Future<BackendStatusResult> getStatus({
    required String serverUrl,
    required String? token,
    required String serverMeetingId,
  }) async {
    final uri = _buildUri(serverUrl, '/api/meetings/$serverMeetingId/status');
    final resp = await _send(() => _client.get(uri, headers: _authHeaders(token)));
    _throwIfError(resp);
    return BackendStatusResult.fromJson(_decodeMap(resp.body));
  }

  Future<BackendMeetingDetail> getMeeting({
    required String serverUrl,
    required String? token,
    required String serverMeetingId,
    required String localMeetingId,
  }) async {
    final uri = _buildUri(serverUrl, '/api/meetings/$serverMeetingId');
    final resp = await _send(() => _client.get(uri, headers: _authHeaders(token)));
    _throwIfError(resp);
    return BackendMeetingDetail.fromJson(
      _decodeMap(resp.body),
      localMeetingId: localMeetingId,
    );
  }

  Future<http.Response> _send(
    Future<http.Response> Function() requestFn, {
    bool isUpload = false,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      return await requestFn().timeout(timeout);
    } on BackendException {
      rethrow;
    } on TimeoutException {
      throw BackendException(
        isUpload
            ? BackendFailureKind.uploadInterrupted
            : BackendFailureKind.serverUnreachable,
        isUpload
            ? 'Upload timed out. Will resume automatically.'
            : 'Server timed out. Check connection and try again.',
      );
    } on SocketException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('cleartext')) {
        throw const BackendException(
          BackendFailureKind.cleartextBlocked,
          'HTTP connections are blocked in release builds. Use an https:// server URL.',
        );
      }
      throw BackendException(
        isUpload
            ? BackendFailureKind.uploadInterrupted
            : BackendFailureKind.serverUnreachable,
        isUpload
            ? 'Connection interrupted during upload. Ready to resume.'
            : 'Cannot reach transcription server. Check URL, Wi-Fi, or adb reverse.',
      );
    } on http.ClientException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('cleartext')) {
        throw const BackendException(
          BackendFailureKind.cleartextBlocked,
          'HTTP connections are blocked in release builds. Use an https:// server URL.',
        );
      }
      throw BackendException(
        isUpload
            ? BackendFailureKind.uploadInterrupted
            : BackendFailureKind.serverUnreachable,
        isUpload
            ? 'Network interrupted while uploading. Will resume from last saved byte.'
            : 'Could not reach server. Verify server address and network.',
      );
    }
  }

  void _throwIfError(http.Response resp, {bool isUpload = false}) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw const BackendException(
        BackendFailureKind.wrongToken,
        'API token rejected by server (401). Check your token in Settings.',
      );
    }
    if (resp.statusCode == 413) {
      throw const BackendException(
        BackendFailureKind.fileTooLarge,
        'Audio recording exceeds the server upload size limit.',
      );
    }
    if (resp.statusCode == 415) {
      throw const BackendException(
        BackendFailureKind.unsupportedAudio,
        'Audio format is not supported by the server.',
      );
    }
    if (resp.statusCode == 429) {
      throw const BackendException(
        BackendFailureKind.rateLimited,
        'Upload rate limit hit. Waiting briefly before retrying.',
      );
    }
    final detail = _tryDecodeMap(resp.body)?['detail']?.toString();
    throw BackendException(
      isUpload
          ? BackendFailureKind.uploadInterrupted
          : BackendFailureKind.unexpected,
      detail != null && detail.isNotEmpty
          ? detail
          : 'Server returned HTTP ${resp.statusCode}.',
    );
  }

  static Map<String, dynamic> _decodeMap(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const BackendException(
      BackendFailureKind.unexpected,
      'Unexpected server response format.',
    );
  }

  static Map<String, dynamic>? _tryDecodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
