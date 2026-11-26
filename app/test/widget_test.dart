import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:minute/main.dart';
import 'package:minute/models/recording_item.dart';
import 'package:minute/services/recording_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SilenceMarker formats exact range and display label', () {
    const marker = SilenceMarker(
      startMs: 135000, // 02:15
      endMs: 340000, // 05:40
      reason: 'Phone/VoIP call silenced mic',
    );
    expect(marker.formattedRange, '02:15-05:40');
    expect(marker.displayLabel, 'Possible silence 02:15-05:40');
  });

  test('RecordingItem serializes force mode and silence markers cleanly', () {
    final created = DateTime.utc(2026, 11, 26, 4, 55, 0);
    final item = RecordingItem(
      id: 'rec_1',
      title: 'Spike Test',
      filePath:
          '/data/user/0/com.izzdzikri.minute/app_flutter/recordings/rec_1.m4a',
      createdAt: created,
      durationMs: 360000,
      sizeBytes: 1440000,
      segmentCount: 12,
      isPartial: false,
      isForceMode: true,
      silenceMarkers: const [
        SilenceMarker(
          startMs: 135000,
          endMs: 340000,
          reason: 'Phone/VoIP call silenced mic',
        ),
      ],
      note: null,
    );

    final decoded = RecordingItem.fromJson(item.toJson());
    expect(decoded.id, item.id);
    expect(decoded.isForceMode, isTrue);
    expect(decoded.silenceMarkers.length, 1);
    expect(decoded.silenceMarkers.first.displayLabel,
        'Possible silence 02:15-05:40');
    expect(decoded.silenceMarkers.first.reason,
        'Phone/VoIP call silenced mic');
  });

  test('PendingSessionMetadata preserves segment order, force mode, and markers',
      () {
    final created = DateTime.utc(2026, 11, 26, 5, 0, 0);
    final meta = PendingSessionMetadata(
      sessionId: 'rec_999',
      title: 'Lecture 1',
      createdAt: created,
      segmentFiles: const ['seg_0001.aac', 'seg_0002.aac', 'seg_0003.aac'],
      elapsedMs: 91200,
      isForceMode: true,
      silenceMarkers: const [
        SilenceMarker(
          startMs: 10000,
          endMs: 22000,
          reason: 'Another app/system silenced mic',
        ),
      ],
      note: 'FORCE recording active',
    );

    final decoded = PendingSessionMetadata.fromJson(meta.toJson());
    expect(decoded.sessionId, 'rec_999');
    expect(decoded.isForceMode, isTrue);
    expect(decoded.silenceMarkers.first.formattedRange, '00:10-00:22');
    expect(decoded.segmentFiles, [
      'seg_0001.aac',
      'seg_0002.aac',
      'seg_0003.aac',
    ]);
  });

  group('SpikeHomeScreen force mode & silence card rendering', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('minute_spike_test_');
      RecordingStorage.testBaseDirectory = tempDir;

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      messenger.setMockMethodCallHandler(
        const MethodChannel('com.izzdzikri.minute/native'),
        (call) async {
          switch (call.method) {
            case 'getAvailableStorageBytes':
              return 4 * 1024 * 1024 * 1024;
            case 'getAudioEnvironmentState':
              return {
                'audioMode': 0,
                'isCallActive': false,
                'isPowerSaveMode': false,
                'isClientSilenced': false,
              };
            default:
              return null;
          }
        },
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('flutter_foreground_task/methods'),
        (call) async {
          switch (call.method) {
            case 'isRunningService':
            case 'isIgnoringBatteryOptimizations':
              return false;
            default:
              return null;
          }
        },
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.ryanheise.audio_session'),
        (call) async => null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.ryanheise.just_audio.methods'),
        (call) async => null,
      );
    });

    tearDown(() async {
      RecordingStorage.testBaseDirectory = null;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      for (final ch in const [
        'com.izzdzikri.minute/native',
        'flutter_foreground_task/methods',
        'com.ryanheise.audio_session',
        'com.ryanheise.just_audio.methods',
      ]) {
        messenger.setMockMethodCallHandler(MethodChannel(ch), null);
      }
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('renders Force toggle & card cleanly at ${scale}x text scale',
          (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final recDir = Directory(p.join(tempDir.path, 'recordings'))
          ..createSync(recursive: true);
        final dummyAudio = File(p.join(recDir.path, 'rec_100.m4a'))
          ..writeAsBytesSync([1, 2, 3, 4]);
        await tester.runAsync(() async {
          await RecordingStorage.saveMetadata(
            RecordingItem(
              id: 'rec_100',
              title: 'Force Test Call',
              filePath: dummyAudio.path,
              createdAt: DateTime.utc(2026, 11, 26, 5, 20),
              durationMs: 360000,
              sizeBytes: 1440000,
              segmentCount: 12,
              isForceMode: true,
              silenceMarkers: const [
                SilenceMarker(
                  startMs: 135000,
                  endMs: 340000,
                  reason: 'Phone/VoIP call silenced mic',
                ),
              ],
            ),
          );
        });

        await tester.pumpWidget(const MinuteSpikeApp());
        await tester.pumpAndSettle();

        expect(find.text('Force record (never pause)'), findsOneWidget);
        await tester.drag(find.byType(ListView), const Offset(0, -520));
        await tester.pump();
        expect(find.text('Saved Recordings (1)'), findsOneWidget);
        expect(find.text('Force Test Call'), findsOneWidget);
        expect(find.text('FORCE'), findsOneWidget);
        expect(find.text('Possible silence 02:15-05:40'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
