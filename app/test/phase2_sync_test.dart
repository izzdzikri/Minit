import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:minit/data/database/app_database.dart';
import 'package:minit/providers/app_providers.dart';
import 'package:minit/router/app_router.dart';
import 'package:minit/services/app_settings.dart';
import 'package:minit/services/backend_api_client.dart';
import 'package:minit/services/markdown_exporter.dart';
import 'package:minit/services/recording_storage.dart';
import 'package:minit/services/secure_token_storage.dart';
import 'package:minit/services/transcription_poller.dart';
import 'package:minit/services/upload_manager.dart';
import 'package:minit/theme/minute_theme.dart';
import 'package:minit/widgets/upload_consent_dialog.dart';

class _InMemoryTokenStorage implements TokenStorage {
  _InMemoryTokenStorage([this._token = 'test-secret-token']);

  String? _token;

  @override
  Future<void> deleteToken() async => _token = null;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async {
    _token = token.trim().isEmpty ? null : token.trim();
  }
}

class _OnlineConnectivity extends ConnectivityNotifier {
  @override
  bool build() => true;
}

Future<void> _pumpAndDrain(WidgetTester tester, {int ticks = 6}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Finder _topVerticalScrollable() => find
    .descendant(
      of: find.byType(Scaffold).last,
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    )
    .first;

Future<void> _scrollIntoSafeViewport(
  WidgetTester tester,
  Finder target,
) async {
  final scroller = _topVerticalScrollable();
  for (var i = 0; i < 20 && target.evaluate().isEmpty; i++) {
    await tester.drag(scroller, const Offset(0, -180));
    await _pumpAndDrain(tester, ticks: 2);
  }
  for (var i = 0; i < 12 && target.evaluate().isNotEmpty; i++) {
    final dy = tester.getCenter(target).dy;
    if (dy >= 120 && dy <= 430) break;
    await tester.drag(scroller, Offset(0, dy < 120 ? 150 : -150));
    await _pumpAndDrain(tester, ticks: 2);
  }
}

void main() {
  group('UploadManager chunked upload, resume & error handling', () {
    test(
      'resumes from server HEAD Upload-Offset after mid-upload socket drop without restarting at 0',
      () async {
        final tmp = await Directory.systemTemp.createTemp('minit_upload_');
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() async {
          await db.close();
          await tmp.delete(recursive: true);
        });

        final audioFile = File('${tmp.path}/sample.m4a');
        final payload = List<int>.generate(25, (i) => (i * 7 + 3) & 0xff);
        await audioFile.writeAsBytes(payload, flush: true);

        final now = DateTime.now();
        await db.into(db.meetings).insert(
          MeetingsCompanion.insert(
            id: 'm_resume',
            title: 'Manglish Sync',
            audioPath: Value(audioFile.path),
            durationMs: const Value(120000),
            sizeBytes: Value(payload.length),
            language: const Value('ms'),
            glossary: const Value('ChatGPT, benchmark'),
            createdAt: now,
            updatedAt: now,
          ),
        );

        final putRanges = <String>[];
        final receivedBuffer = <int>[];
        var failSecondChunkOnce = true;

        final mockClient = MockClient((req) async {
          final auth = req.headers['Authorization'];
          if (auth != 'Bearer test-secret-token') {
            return http.Response('{"detail":"Unauthorized"}', 401);
          }
          if (req.method == 'POST' && req.url.path == '/api/meetings') {
            return http.Response(
              jsonEncode({'id': 'srv_resume_1', 'status': 'uploading'}),
              201,
            );
          }
          if (req.method == 'HEAD' &&
              req.url.path == '/api/meetings/srv_resume_1/upload') {
            return http.Response(
              '',
              200,
              headers: {
                'upload-offset': '${receivedBuffer.length}',
                'upload-length': '${payload.length}',
                'x-upload-status':
                    receivedBuffer.length >= payload.length
                        ? 'completed'
                        : 'uploading',
              },
            );
          }
          if (req.method == 'PUT' &&
              req.url.path == '/api/meetings/srv_resume_1/upload') {
            final rangeHeader = req.headers['Content-Range']!;
            putRanges.add(rangeHeader);
            final match = RegExp(
              r'bytes (\d+)-(\d+)/(\d+)',
            ).firstMatch(rangeHeader)!;
            final start = int.parse(match.group(1)!);
            final end = int.parse(match.group(2)!);
            if (start == 10 && failSecondChunkOnce) {
              failSecondChunkOnce = false;
              throw const SocketException('Connection reset mid-upload');
            }
            expect(start, receivedBuffer.length);
            expect(req.bodyBytes.length, end - start + 1);
            receivedBuffer.addAll(req.bodyBytes);
            final complete = receivedBuffer.length >= payload.length;
            return http.Response(
              jsonEncode({
                'received_bytes': receivedBuffer.length,
                'complete': complete,
                'status': complete ? 'queued' : 'uploading',
              }),
              200,
            );
          }
          if (req.method == 'POST' &&
              req.url.path == '/api/meetings/srv_resume_1/process') {
            return http.Response(
              jsonEncode({
                'status': 'queued',
                'progress_percent': 5,
                'message': 'Queued for transcription.',
              }),
              200,
            );
          }
          return http.Response('Not found', 404);
        });

        final completedCallbacks = <String>[];
        final manager = UploadManager(
          db: db,
          api: BackendApiClient(httpClient: mockClient),
          tokenStorage: _InMemoryTokenStorage(),
          loadSettings: () async => const AppSettings(
            serverUrl: 'http://localhost:8000',
            wifiOnlyUpload: false,
            autoUpload: true,
            consentedServerUrl: 'http://localhost:8000',
          ),
          checkConnectivity: () async => [ConnectivityResult.wifi],
          connectivityStream: () => const Stream.empty(),
          delayFn: (_) async {},
          chunkSizeBytes: 10,
          onUploadComplete: completedCallbacks.add,
        );
        addTearDown(manager.dispose);

        await manager.enqueueAndProcess('m_resume');

        // Notice chunk 0-9 was uploaded ONCE, chunk 10-19 failed once then
        // resumed from offset 10 without ever re-uploading 0-9!
        expect(putRanges, [
          'bytes 0-9/25',
          'bytes 10-19/25',
          'bytes 10-19/25',
          'bytes 20-24/25',
        ]);
        expect(receivedBuffer, payload);

        final updated = await db.getMeetingById('m_resume');
        expect(updated?.status, 'Queued');
        expect(updated?.uploadProgress, 100);
        expect(updated?.serverMeetingId, 'srv_resume_1');
        expect(completedCallbacks, ['m_resume']);
      },
    );

    test(
      'simulated app kill mid-upload resumes from server offset on processPendingUploads',
      () async {
        final tmp = await Directory.systemTemp.createTemp('minit_kill_');
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() async {
          await db.close();
          await tmp.delete(recursive: true);
        });

        final audioFile = File('${tmp.path}/killed.m4a');
        final payload = List<int>.generate(20, (i) => i + 50);
        await audioFile.writeAsBytes(payload, flush: true);

        final now = DateTime.now();
        await db.into(db.meetings).insert(
          MeetingsCompanion.insert(
            id: 'm_kill',
            title: 'Killed Mid Upload',
            audioPath: Value(audioFile.path),
            sizeBytes: Value(payload.length),
            serverMeetingId: const Value('srv_kill_1'),
            status: const Value('Uploading'),
            uploadProgress: const Value(50),
            createdAt: now,
            updatedAt: now,
          ),
        );
        await db.upsertUploadQueueEntry(
          meetingId: 'm_kill',
          filePath: audioFile.path,
          totalBytes: payload.length,
          uploadedBytes: 10,
          status: 'uploading',
        );

        final rangesSeen = <String>[];
        final serverBytes = List<int>.from(payload.sublist(0, 10));

        final client = MockClient((req) async {
          if (req.method == 'HEAD' &&
              req.url.path == '/api/meetings/srv_kill_1/upload') {
            return http.Response(
              '',
              200,
              headers: {
                'upload-offset': '${serverBytes.length}',
                'upload-length': '${payload.length}',
                'x-upload-status': 'uploading',
              },
            );
          }
          if (req.method == 'PUT' &&
              req.url.path == '/api/meetings/srv_kill_1/upload') {
            rangesSeen.add(req.headers['Content-Range']!);
            serverBytes.addAll(req.bodyBytes);
            return http.Response(
              jsonEncode({
                'received_bytes': serverBytes.length,
                'complete': true,
                'status': 'queued',
              }),
              200,
            );
          }
          if (req.method == 'POST' &&
              req.url.path == '/api/meetings/srv_kill_1/process') {
            return http.Response(
              jsonEncode({'status': 'queued', 'progress_percent': 10}),
              200,
            );
          }
          return http.Response('Unexpected ${req.method} ${req.url}', 500);
        });

        final newManager = UploadManager(
          db: db,
          api: BackendApiClient(httpClient: client),
          tokenStorage: _InMemoryTokenStorage(),
          loadSettings: () async => const AppSettings(
            wifiOnlyUpload: false,
            consentedServerUrl: 'http://localhost:8000',
          ),
          checkConnectivity: () async => [ConnectivityResult.wifi],
          connectivityStream: () => const Stream.empty(),
          delayFn: (_) async {},
          chunkSizeBytes: 10,
        );
        addTearDown(newManager.dispose);

        await newManager.processPendingUploads();

        expect(rangesSeen, ['bytes 10-19/20']);
        expect(serverBytes, payload);
        expect((await db.getMeetingById('m_kill'))?.status, 'Queued');
      },
    );

    test(
      'pauses on cellular when Wi-Fi only is on and auto-resumes when Wi-Fi returns',
      () async {
        final tmp = await Directory.systemTemp.createTemp('minit_wifi_');
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() async {
          await db.close();
          await tmp.delete(recursive: true);
        });

        final audioFile = File('${tmp.path}/wifi_test.m4a');
        await audioFile.writeAsBytes([1, 2, 3, 4, 5], flush: true);

        final now = DateTime.now();
        await db.into(db.meetings).insert(
          MeetingsCompanion.insert(
            id: 'm_wifi',
            title: 'Wi-Fi Guarded',
            audioPath: Value(audioFile.path),
            sizeBytes: const Value(5),
            createdAt: now,
            updatedAt: now,
          ),
        );

        var currentNet = [ConnectivityResult.mobile];
        final connController =
            StreamController<List<ConnectivityResult>>.broadcast();
        addTearDown(connController.close);
        var uploadRequests = 0;

        final client = MockClient((req) async {
          uploadRequests++;
          if (req.method == 'POST' && req.url.path == '/api/meetings') {
            return http.Response(jsonEncode({'id': 'srv_w'}), 201);
          }
          if (req.method == 'HEAD') {
            return http.Response(
              '',
              200,
              headers: {'upload-offset': '0', 'upload-length': '5'},
            );
          }
          if (req.method == 'PUT') {
            return http.Response(
              jsonEncode({'received_bytes': 5, 'complete': true}),
              200,
            );
          }
          if (req.method == 'POST' && req.url.path.endsWith('/process')) {
            return http.Response(
              jsonEncode({'status': 'queued', 'progress_percent': 5}),
              200,
            );
          }
          return http.Response('err', 500);
        });

        final manager = UploadManager(
          db: db,
          api: BackendApiClient(httpClient: client),
          tokenStorage: _InMemoryTokenStorage(),
          loadSettings: () async => const AppSettings(
            wifiOnlyUpload: true,
            consentedServerUrl: 'http://localhost:8000',
          ),
          checkConnectivity: () async => currentNet,
          connectivityStream: () => connController.stream,
          delayFn: (_) async {},
        );
        addTearDown(manager.dispose);

        await manager.startListening();
        await manager.enqueueAndProcess('m_wifi');

        // Zero HTTP requests made while on mobile data.
        expect(uploadRequests, 0);
        final paused = await db.getMeetingById('m_wifi');
        expect(paused?.status, 'Uploading');
        expect(paused?.statusMessage, contains('Waiting for Wi-Fi'));

        // Switch to Wi-Fi and fire connectivity event -> resumes automatically!
        currentNet = [ConnectivityResult.wifi];
        connController.add([ConnectivityResult.wifi]);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(uploadRequests, greaterThanOrEqualTo(3));
        expect((await db.getMeetingById('m_wifi'))?.status, 'Queued');
      },
    );

    test(
      'maps 401 wrong token, 413 payload too large, and cleartext block to clear error states',
      () async {
        final tmp = await Directory.systemTemp.createTemp('minit_err_');
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() async {
          await db.close();
          await tmp.delete(recursive: true);
        });

        final audioFile = File('${tmp.path}/err.m4a');
        await audioFile.writeAsBytes([9, 8, 7], flush: true);

        Future<void> insertMeeting(String id) async {
          final now = DateTime.now();
          await db.into(db.meetings).insert(
            MeetingsCompanion.insert(
              id: id,
              title: 'Err $id',
              audioPath: Value(audioFile.path),
              sizeBytes: const Value(3),
              createdAt: now,
              updatedAt: now,
            ),
          );
        }

        await insertMeeting('m_401');
        final badTokenClient = MockClient(
          (_) async => http.Response('{"detail":"Invalid token"}', 401),
        );
        final m1 = UploadManager(
          db: db,
          api: BackendApiClient(httpClient: badTokenClient),
          tokenStorage: _InMemoryTokenStorage('wrong-token'),
          loadSettings: () async => const AppSettings(
            wifiOnlyUpload: false,
            consentedServerUrl: 'http://localhost:8000',
          ),
          checkConnectivity: () async => [ConnectivityResult.wifi],
          connectivityStream: () => const Stream.empty(),
          delayFn: (_) async {},
        );
        addTearDown(m1.dispose);
        await m1.enqueueAndProcess('m_401');
        final row401 = await db.getMeetingById('m_401');
        expect(row401?.status, 'Failed');
        expect(row401?.statusMessage, contains('401'));

        await insertMeeting('m_413');
        final tooBigClient = MockClient(
          (_) async => http.Response('{"detail":"Too large"}', 413),
        );
        final m2 = UploadManager(
          db: db,
          api: BackendApiClient(httpClient: tooBigClient),
          tokenStorage: _InMemoryTokenStorage(),
          loadSettings: () async => const AppSettings(
            wifiOnlyUpload: false,
            consentedServerUrl: 'http://localhost:8000',
          ),
          checkConnectivity: () async => [ConnectivityResult.wifi],
          connectivityStream: () => const Stream.empty(),
          delayFn: (_) async {},
        );
        addTearDown(m2.dispose);
        await m2.enqueueAndProcess('m_413');
        final row413 = await db.getMeetingById('m_413');
        expect(row413?.status, 'Failed');
        expect(row413?.statusMessage, contains('upload size limit'));

        // Verify cleartext HTTP rejection surfaces cleartextBlocked clearly.
        final cleartextApi = BackendApiClient(
          httpClient: MockClient((_) async {
            throw const SocketException(
              'Cleartext HTTP traffic to localhost not permitted',
            );
          }),
        );
        expect(
          () => cleartextApi.testHealth(
            serverUrl: 'http://example.com',
            token: 'abc',
          ),
          throwsA(
            isA<BackendException>().having(
              (e) => e.kind,
              'kind',
              BackendFailureKind.cleartextBlocked,
            ),
          ),
        );
      },
    );
  });

  group('MeetingStatusPoller stop conditions & transcript persistence', () {
    test(
      'stops immediately on ready, saves confidence scores + loop flags, notifies once, and feeds Copy for AI',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final now = DateTime.now();
        await db.into(db.meetings).insert(
          MeetingsCompanion.insert(
            id: 'm_poll',
            title: 'Sprint Review',
            serverMeetingId: const Value('srv_poll_1'),
            status: const Value('Queued'),
            createdAt: now,
            updatedAt: now,
          ),
        );

        var statusCalls = 0;
        final notifiedTitles = <String>[];
        final client = MockClient((req) async {
          if (req.url.path == '/api/meetings/srv_poll_1/status') {
            statusCalls++;
            if (statusCalls == 1) {
              return http.Response(
                jsonEncode({
                  'status': 'transcribing',
                  'progress_percent': 45,
                  'message': 'Transcribing chunk 1/2',
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'status': 'ready',
                'progress_percent': 100,
                'message': 'Ready',
              }),
              200,
            );
          }
          if (req.url.path == '/api/meetings/srv_poll_1') {
            return http.Response(
              jsonEncode({
                'id': 'srv_poll_1',
                'client_meeting_id': 'm_poll',
                'status': 'ready',
                'progress_percent': 100,
                'status_message': 'Ready',
                'detected_language': 'ms',
                'duration_sec': 45.0,
                'segments': [
                  {
                    'id': 1,
                    'speaker_label': 'Speaker 1',
                    'start_sec': 0.0,
                    'end_sec': 5.2,
                    'text': 'Okay kita check benchmark model dulu.',
                    'avg_logprob': -0.22,
                    'no_speech_prob': 0.05,
                    'is_loop_flagged': false,
                  },
                  {
                    'id': 2,
                    'speaker_label': 'Speaker 1',
                    'start_sec': 5.5,
                    'end_sec': 11.0,
                    'text': 'Unclear synthetic phrase',
                    'avg_logprob': -0.78,
                    'no_speech_prob': 0.12,
                    'is_loop_flagged': false,
                  },
                  {
                    'id': 3,
                    'speaker_label': 'Speaker 1',
                    'start_sec': 12.0,
                    'end_sec': 16.0,
                    'text': 'lah lah lah lah lah',
                    'avg_logprob': -0.45,
                    'no_speech_prob': 0.62,
                    'is_loop_flagged': true,
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('unexpected', 500);
        });

        final poller = MeetingStatusPoller(
          db: db,
          api: BackendApiClient(httpClient: client),
          tokenStorage: _InMemoryTokenStorage(),
          loadServerUrl: () async => 'http://localhost:8000',
          notifyReady: ({required meetingId, required title}) async {
            notifiedTitles.add('$meetingId:$title');
            return true;
          },
          delayFn: (_) async {},
        );
        addTearDown(poller.dispose);

        await poller.pollUntilTerminal('m_poll');

        expect(statusCalls, 2);
        expect(poller.isRunning, isFalse);
        expect(notifiedTitles, ['m_poll:Sprint Review']);

        final detail = await db.getMeetingDetail('m_poll');
        expect(detail?.meeting.status, 'Ready');
        expect(detail?.segments.length, 3);
        expect(detail!.segments[1].segment.avgLogprob, closeTo(-0.78, 1e-6));
        expect(detail.segments[2].segment.isLoopFlagged, isTrue);

        // Export ("Copy for AI") picks up the new transcript automatically.
        final md = MarkdownExporter.generate(detail, ExportMode.fullWithAiPrompt);
        expect(md, contains('Okay kita check benchmark model dulu.'));
        expect(md, contains('Unclear synthetic phrase'));
      },
    );

    test('stops immediately on failed and cancels cleanly on dispose()', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final now = DateTime.now();
      await db.into(db.meetings).insert(
        MeetingsCompanion.insert(
          id: 'm_fail',
          title: 'Failing Job',
          serverMeetingId: const Value('srv_fail'),
          status: const Value('Transcribing'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.into(db.meetings).insert(
        MeetingsCompanion.insert(
          id: 'm_disp',
          title: 'Disposed Screen',
          serverMeetingId: const Value('srv_disp'),
          status: const Value('Queued'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      var failCalls = 0;
      final failPoller = MeetingStatusPoller(
        db: db,
        api: BackendApiClient(
          httpClient: MockClient((_) async {
            failCalls++;
            return http.Response(
              jsonEncode({
                'status': 'failed',
                'progress_percent': 20,
                'error_message': 'Audio decode failed.',
              }),
              200,
            );
          }),
        ),
        tokenStorage: _InMemoryTokenStorage(),
        loadServerUrl: () async => 'http://localhost:8000',
        delayFn: (_) async {},
      );
      await failPoller.pollUntilTerminal('m_fail');
      expect(failCalls, 1);
      final failedRow = await db.getMeetingById('m_fail');
      expect(failedRow?.status, 'Failed');
      expect(failedRow?.statusMessage, 'Audio decode failed.');

      var dispCalls = 0;
      final delayGate = Completer<void>();
      final dispPoller = MeetingStatusPoller(
        db: db,
        api: BackendApiClient(
          httpClient: MockClient((_) async {
            dispCalls++;
            return http.Response(
              jsonEncode({'status': 'queued', 'progress_percent': 10}),
              200,
            );
          }),
        ),
        tokenStorage: _InMemoryTokenStorage(),
        loadServerUrl: () async => 'http://localhost:8000',
        delayFn: (_) => delayGate.future,
      );
      final future = dispPoller.pollUntilTerminal('m_disp');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(dispCalls, 1);
      dispPoller.dispose();
      delayGate.complete();
      await future;
      // Zero extra HTTP requests after dispose().
      expect(dispCalls, 1);
    });
  });

  group('Phase 2 UI tests at 1.0x and 2.0x text scale', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Settings, Record Auto warning, Glossary, Consent dialog, Library Failed Retry chip, and Low-Confidence Transcript render cleanly at ${scale}x',
        (tester) async {
          final tmp = Directory.systemTemp.createTempSync('minit_ui2_');
          RecordingStorage.testBaseDirectory = tmp;
          AppSettingsStorage.testBaseDirectory = tmp;
          await tester.runAsync(
            () => AppSettingsStorage.save(const AppSettings()),
          );

          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
            const MethodChannel('com.izzdzikri.minit/native'),
            (call) async => null,
          );

          final db = AppDatabase(NativeDatabase.memory());
          addTearDown(() async {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(
              const MethodChannel('com.izzdzikri.minit/native'),
              null,
            );
            RecordingStorage.testBaseDirectory = null;
            AppSettingsStorage.testBaseDirectory = null;
            await tester.runAsync(() async {
              await db.close();
              if (tmp.existsSync()) {
                tmp.deleteSync(recursive: true);
              }
            });
          });

          // Seed a Failed meeting + a Ready meeting with confident + low-confidence + loop segments.
          final now = DateTime.now();
          await tester.runAsync(() async {
            await db.into(db.meetings).insert(
              MeetingsCompanion.insert(
                id: 'm_ui_failed',
                title: 'Failed Upload Meeting',
                status: const Value('Failed'),
                statusMessage: const Value(
                  'API token rejected by server (401). Check your token in Settings.',
                ),
                createdAt: now,
                updatedAt: now,
              ),
            );
            await db.into(db.meetings).insert(
              MeetingsCompanion.insert(
                id: 'm_ui_ready',
                title: 'Mixed Meeting Transcript',
                status: const Value('Ready'),
                language: const Value('ms'),
                glossary: const Value('ChatGPT, benchmark'),
                durationMs: const Value(65000),
                createdAt: now.subtract(const Duration(minutes: 5)),
                updatedAt: now,
              ),
            );
            await db.replaceMeetingTranscript(
              meetingId: 'm_ui_ready',
              detectedLanguage: 'ms',
              segmentDrafts: const [
                TranscriptSegmentDraft(
                  id: 'seg_ok',
                  speakerLabel: 'Speaker 1',
                  startSec: 0.0,
                  endSec: 4.5,
                  textContent: 'Kita run benchmark dulu.',
                  avgLogprob: -0.20,
                  noSpeechProb: 0.04,
                  isLoopFlagged: false,
                ),
                TranscriptSegmentDraft(
                  id: 'seg_low',
                  speakerLabel: 'Speaker 1',
                  startSec: 5.0,
                  endSec: 9.0,
                  textContent: 'Mungkin sintetik data kurang jelas.',
                  avgLogprob: -0.82,
                  noSpeechProb: 0.15,
                  isLoopFlagged: false,
                ),
                TranscriptSegmentDraft(
                  id: 'seg_loop',
                  speakerLabel: 'Speaker 1',
                  startSec: 10.0,
                  endSec: 14.0,
                  textContent: 'ok ok ok ok ok ok',
                  avgLogprob: -0.40,
                  noSpeechProb: 0.10,
                  isLoopFlagged: true,
                ),
              ],
            );
          });

          final fakeTokens = _InMemoryTokenStorage('valid-token');
          final mockApi = BackendApiClient(
            httpClient: MockClient((req) async {
              if (req.url.path == '/api/health') {
                return http.Response(
                  jsonEncode({
                    'status': 'ok',
                    'model': 'medium',
                    'compute_type': 'int8',
                    'default_language': 'ms',
                  }),
                  200,
                );
              }
              return http.Response('{}', 200);
            }),
          );

          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          final router = createAppRouter(initialLocation: '/library');
          addTearDown(router.dispose);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appDatabaseProvider.overrideWithValue(db),
                connectivityOnlineProvider.overrideWith(
                  _OnlineConnectivity.new,
                ),
                settingsPersistProvider.overrideWithValue((_) async {}),
                tokenStorageProvider.overrideWithValue(fakeTokens),
                backendApiClientProvider.overrideWithValue(mockApi),
              ],
              child: MaterialApp.router(
                theme: MinuteTheme.light(),
                routerConfig: router,
              ),
            ),
          );
          await _pumpAndDrain(tester);

          // 1) Library: shows Failed chip, concise error, and Retry ActionChip.
          expect(find.text('Failed Upload Meeting'), findsOneWidget);
          expect(find.text('Retry'), findsOneWidget);
          expect(tester.takeException(), isNull);

          // 2) Navigate to Ready meeting detail: check Summary placeholder + Transcript markings.
          await tester.tap(find.text('Mixed Meeting Transcript'));
          await _pumpAndDrain(tester);
          await tester.scrollUntilVisible(
            find.textContaining('later phase'),
            150,
            scrollable: _topVerticalScrollable(),
          );
          expect(
            find.textContaining('later phase'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);

          await tester.scrollUntilVisible(
            find.text('Transcript'),
            -150,
            scrollable: _topVerticalScrollable(),
          );
          await tester.tap(find.text('Transcript'));
          await _pumpAndDrain(tester);
          await tester.scrollUntilVisible(
            find.textContaining('Dashed amber underline'),
            150,
            scrollable: _topVerticalScrollable(),
          );
          expect(
            find.textContaining('Dashed amber underline'),
            findsOneWidget,
          );
          await tester.scrollUntilVisible(
            find.text('ok ok ok ok ok ok'),
            150,
            scrollable: _topVerticalScrollable(),
          );
          expect(find.text('Kita run benchmark dulu.'), findsOneWidget);
          // Low-confidence and loop segments remain visible (never hidden) and marked.
          expect(
            find.text('Mungkin sintetik data kurang jelas.'),
            findsOneWidget,
          );
          expect(find.text('ok ok ok ok ok ok'), findsOneWidget);
          expect(find.text('Low confidence'), findsOneWidget);
          expect(find.text('Possible loop'), findsOneWidget);
          final lowTextWidget = tester.widget<Text>(
            find.text('Mungkin sintetik data kurang jelas.'),
          );
          expect(
            lowTextWidget.style?.decorationStyle,
            TextDecorationStyle.dashed,
          );
          expect(tester.takeException(), isNull);

          // Pop back to Library, then check Settings Test connection + Auto warning.
          await tester.tap(find.byTooltip('Back'));
          await _pumpAndDrain(tester);
          await tester.tap(find.text('Settings'));
          await _pumpAndDrain(tester);

          expect(find.text('Test connection'), findsOneWidget);
          await tester.ensureVisible(find.text('Test connection'));
          await tester.tap(find.text('Test connection'));
          await _pumpAndDrain(tester);
          expect(
            find.textContaining('Connected (medium int8, default ms).'),
            findsOneWidget,
          );

          await _scrollIntoSafeViewport(tester, find.text('Auto'));
          await tester.tap(find.text('Auto'));
          await _pumpAndDrain(tester);
          await _scrollIntoSafeViewport(
            tester,
            find.text('Auto detects from the first 30 seconds only.'),
          );
          expect(
            find.text('Auto detects from the first 30 seconds only.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);

          // 3) Check Consent dialog and Record screen Auto warning & Glossary field.
          await tester.tap(find.text('Record'));
          await _pumpAndDrain(tester);
          await _scrollIntoSafeViewport(
            tester,
            find.text('Glossary hints (optional)'),
          );
          expect(find.text('Glossary hints (optional)'), findsOneWidget);
          await _scrollIntoSafeViewport(tester, find.text('Auto'));
          await tester.tap(find.text('Auto'));
          await _pumpAndDrain(tester);
          await _scrollIntoSafeViewport(
            tester,
            find.text('Auto detects from the first 30 seconds only.'),
          );
          expect(
            find.text('Auto detects from the first 30 seconds only.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);

          // Render consent dialog explicitly and check server URL & zero overflow.
          final navContext = tester.element(find.text('Glossary hints (optional)'));
          unawaited(
            showUploadConsentDialog(
              navContext,
              serverUrl: 'http://192.168.1.50:8000',
            ),
          );
          await _pumpAndDrain(tester);
          expect(find.text('Send audio for transcription?'), findsOneWidget);
          expect(
            find.textContaining('http://192.168.1.50:8000'),
            findsOneWidget,
          );
          await tester.tap(find.text('Allow upload'));
          await _pumpAndDrain(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
