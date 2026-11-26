import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:minit/data/database/app_database.dart';
import 'package:minit/data/demo/demo_meeting_seed.dart';
import 'package:minit/models/recording_item.dart';
import 'package:minit/providers/app_providers.dart';
import 'package:minit/router/app_router.dart';
import 'package:minit/services/app_settings.dart';
import 'package:minit/services/recording_storage.dart';
import 'package:minit/theme/minute_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 0 carry-over models & settings', () {
    test('TimelineMarker formats silence range and call gaps cleanly', () {
      const silence = SilenceMarker(
        type: MarkerType.silence,
        startMs: 135000, // 02:15
        endMs: 340000, // 05:40
        reason: 'Mic silenced',
      );
      expect(silence.formattedRange, '02:15-05:40');
      expect(silence.displayLabel, 'Possible silence 02:15-05:40');

      const callGap = TimelineMarker(
        type: MarkerType.callGap,
        startMs: 60000,
        reason: 'Incoming phone call',
        gapDurationMs: 25000,
      );
      expect(callGap.displayLabel, 'Call interruption at 01:00 (00:25)');
    });

    test('AppSettings defaults otherAppAudioBehavior to keepRecording', () {
      const settings = AppSettings();
      expect(settings.otherAppAudioBehavior, OtherAppAudioBehavior.keepRecording);

      final roundtrip = AppSettings.fromJson(
        settings.copyWith(forceRecordMode: true).toJson(),
      );
      expect(
        roundtrip.otherAppAudioBehavior,
        OtherAppAudioBehavior.keepRecording,
      );
      expect(roundtrip.forceRecordMode, isTrue);
    });
  });

  group('Drift database & search', () {
    late AppDatabase db;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('minute_db_test_');
      RecordingStorage.testBaseDirectory = tempDir;
      AppSettingsStorage.testBaseDirectory = tempDir;
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
      RecordingStorage.testBaseDirectory = null;
      AppSettingsStorage.testBaseDirectory = null;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('demo seed inserts speakers, segments, summary, action items, and peaks',
        () async {
      final id = await DemoMeetingSeed.insertDemoMeeting(db);
      final list = await db.listMeetings();
      expect(list.length, 1);
      expect(list.first.meeting.id, id);

      final detail = await db.getMeetingDetail(id);
      expect(detail, isNotNull);
      expect(detail!.speakers.length, 3);
      expect(detail.segments.length, greaterThan(4));
      expect(detail.summary, isNotNull);
      expect(detail.actionItems.length, greaterThan(2));
      expect(File(detail.meeting.peaksPath!).existsSync(), isTrue);

      // Search matches Manglish transcript text and returns seekSec
      final hits = await db.searchMeetingsAndTranscripts('Semalam');
      expect(hits.length, 1);
      expect(hits.first.seekSec, isNotNull);

      // Rename, toggle action item, edit transcript line
      await db.updateMeetingTitle(id, 'Updated Title');
      await db.toggleActionItem(detail.actionItems.first.id, true);
      await db.updateSegmentText(
        detail.segments.first.segment.id,
        'Edited opening statement.',
      );

      final reloaded = await db.getMeetingDetail(id);
      expect(reloaded!.meeting.title, 'Updated Title');
      expect(reloaded.actionItems.first.done, isTrue);
      expect(reloaded.segments.first.segment.edited, isTrue);
      expect(
        reloaded.segments.first.segment.textContent,
        'Edited opening statement.',
      );

      // Soft delete + restore + hard delete
      await db.setMeetingSoftDeleted(id, true);
      expect(await db.listMeetings(), isEmpty);
      await db.setMeetingSoftDeleted(id, false);
      expect((await db.listMeetings()).length, 1);
      await db.hardDeleteMeeting(id);
      expect(await db.listMeetings(), isEmpty);
    });
  });

  group('Phase 1 UI & 200% font scale resilience', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('minute_ui_test_');
      RecordingStorage.testBaseDirectory = tempDir;
      AppSettingsStorage.testBaseDirectory = tempDir;

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.izzdzikri.minit/native'),
        (call) async {
          switch (call.method) {
            case 'isNetworkOnline':
              return true;
            case 'getAvailableStorageBytes':
              return 8 * 1024 * 1024 * 1024;
            case 'getAudioEnvironmentState':
              return {
                'isCallActive': false,
                'hasHeadset': false,
                'isPowerSaveMode': false,
              };
            case 'getDeviceInfo':
              return {'manufacturer': 'google', 'model': 'Pixel'};
            default:
              return null;
          }
        },
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.izzdzikri.minit/playback_stub'),
        (call) async => null,
      );
    });

    tearDown(() async {
      RecordingStorage.testBaseDirectory = null;
      AppSettingsStorage.testBaseDirectory = null;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> pumpMinuteShell(
      WidgetTester tester, {
      required AppDatabase db,
      double textScale = 1.0,
      String initialLocation = '/library',
    }) async {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final router = createAppRouter(initialLocation: initialLocation);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            connectivityOnlineProvider.overrideWith(() => _OnlineTrueNotifier()),
          ],
          child: MaterialApp.router(
            theme: MinuteTheme.light(),
            darkTheme: MinuteTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 40));
      }
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Library, Record, Search, Settings render with zero overflow at ${scale}x scale',
        (tester) async {
          final db = AppDatabase(NativeDatabase.memory());
          addTearDown(() => tester.runAsync(db.close));

          await tester.runAsync(() async {
            await DemoMeetingSeed.insertDemoMeeting(db);
          });

          await pumpMinuteShell(tester, db: db, textScale: scale);

          // Library screen with demo card & nav shell
          expect(find.text('Minit'), findsOneWidget);
          expect(find.text('Record'), findsOneWidget);
          expect(
            find.text('Minit Sprint Sync & Manglish Audio Review'),
            findsOneWidget,
          );

          // Navigate to Search tab and test query + result card
          await tester.tap(find.text('Search'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.text('Search titles & transcripts'), findsOneWidget);
          await tester.enterText(find.byType(TextField), 'Semalam');
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.text('00:28'), findsOneWidget);

          // Navigate to Settings tab
          await tester.tap(find.text('Settings'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.scrollUntilVisible(
            find.text('When another app plays audio'),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('When another app plays audio'), findsOneWidget);

          // Open Record screen via centered Record button
          await tester.tap(find.text('Record'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          await tester.scrollUntilVisible(
            find.text('Start recording'),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('Start recording'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('Force record (never pause)'),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('Force record (never pause)'), findsOneWidget);
        },
      );

      testWidgets(
        'Meeting Detail renders Summary, Transcript, Export sheet cleanly at ${scale}x',
        (tester) async {
          final db = AppDatabase(NativeDatabase.memory());
          addTearDown(() => tester.runAsync(db.close));

          late final String demoId;
          await tester.runAsync(() async {
            demoId = await DemoMeetingSeed.insertDemoMeeting(db);
          });

          await pumpMinuteShell(
            tester,
            db: db,
            textScale: scale,
            initialLocation: '/meeting/$demoId',
          );

          final listScrollable = find.byType(Scrollable).first;
          await tester.scrollUntilVisible(
            find.text('Audio timeline'),
            120,
            scrollable: listScrollable,
          );
          expect(find.text('Audio timeline'), findsOneWidget);

          await tester.scrollUntilVisible(
            find.text('Summary'),
            120,
            scrollable: listScrollable,
          );
          expect(find.text('Summary'), findsOneWidget);
          expect(find.text('Transcript'), findsOneWidget);

          // Switch to Transcript tab while tab pills are visible
          await tester.ensureVisible(find.text('Transcript'));
          await tester.tap(find.text('Transcript'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 150));

          await tester.scrollUntilVisible(
            find.textContaining('Okay guys, kita mula terus'),
            120,
            scrollable: listScrollable,
          );
          expect(find.textContaining('Okay guys, kita mula terus'), findsOneWidget);

          // Open Export sheet via AppBar share icon
          await tester.tap(find.byTooltip('Export or Copy for AI'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          expect(find.text('Export & Copy for AI'), findsOneWidget);
          expect(find.text('Copy for AI'), findsOneWidget);
        },
      );
    }
  });
}

class _OnlineTrueNotifier extends ConnectivityNotifier {
  @override
  bool build() => true;
}
