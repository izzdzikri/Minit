import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:minit/data/database/app_database.dart';
import 'package:minit/data/demo/demo_meeting_seed.dart';
import 'package:minit/main.dart';
import 'package:minit/providers/app_providers.dart';
import 'package:minit/router/app_router.dart';
import 'package:minit/services/app_settings.dart';
import 'package:minit/services/playback_controller.dart';
import 'package:minit/services/recording_storage.dart';

class _OnlineTrueNotifier extends ConnectivityNotifier {
  @override
  bool build() => true;
}

class _TestRecordingController extends RecordingController {
  @override
  RecordingUiState build() => const RecordingUiState();

  @override
  Future<void> refreshDeviceStatus() async {}

  @override
  Future<void> syncWithRunningService() async {}

  void simulateRecordingActive() {
    state = state.copyWith(
      status: RecorderStatus.recording,
      elapsed: const Duration(seconds: 4),
    );
  }

  void simulateSavedMeeting(String id) {
    state = state.copyWith(
      status: RecorderStatus.idle,
      lastSavedMeetingId: id,
    );
  }

  void simulateNotificationTap() {
    state = state.copyWith(
      status: RecorderStatus.recording,
      openRecordRequestSeq: state.openRecordRequestSeq + 1,
    );
  }
}

class _SpyPlaybackController extends PlaybackController {
  int stopCalls = 0;

  @override
  Future<void> stop() async {
    stopCalls++;
    await super.stop();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('minute_nav_test_');
    RecordingStorage.testBaseDirectory = tempDir;
    AppSettingsStorage.testBaseDirectory = tempDir;

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.izzdzikri.minit/native'),
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

  Future<void> settleAsync(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pumpAndSettle();
  }

  Future<({GoRouter router, _TestRecordingController rec, _SpyPlaybackController playback})>
      pumpApp(
    WidgetTester tester, {
    required AppDatabase db,
    String initialLocation = '/library',
  }) async {
    final router = createAppRouter(initialLocation: initialLocation);
    addTearDown(router.dispose);
    final recController = _TestRecordingController();
    final spyPlayback = _SpyPlaybackController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          connectivityOnlineProvider.overrideWith(_OnlineTrueNotifier.new),
          recordingControllerProvider.overrideWith(() => recController),
          playbackControllerProvider.overrideWith((ref) {
            ref.onDispose(spyPlayback.dispose);
            return spyPlayback;
          }),
          appRouterProvider.overrideWithValue(router),
        ],
        child: const MinitApp(),
      ),
    );
    await settleAsync(tester);
    return (router: router, rec: recController, playback: spyPlayback);
  }

  testWidgets(
      'Record -> Stop & Save -> Detail -> Back arrow & System back land on Library; root Library back exits',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(db.close));
    late final String demoId;
    await tester.runAsync(() async {
      demoId = await DemoMeetingSeed.insertDemoMeeting(db);
    });

    final env = await pumpApp(tester, db: db);

    // At root Library, cannot pop further (system back exits normally).
    expect(find.text('Minit'), findsOneWidget);
    expect(env.router.canPop(), isFalse);
    expect(find.byTooltip('Back'), findsNothing);

    // Open Record via centered Record CTA
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    expect(find.text('Start recording'), findsOneWidget);
    expect(env.router.canPop(), isTrue);
    expect(find.byTooltip('Back'), findsOneWidget);

    // Simulate Stop & Save completing
    env.rec.simulateSavedMeeting(demoId);
    await settleAsync(tester);

    // Stack must be Library > MeetingDetail with leading Back button
    expect(find.text('Audio timeline'), findsOneWidget);
    expect(env.router.canPop(), isTrue);
    expect(find.byTooltip('Back'), findsOneWidget);

    // Tapping AppBar Back arrow returns to Library and stops playback
    final prevStops = env.playback.stopCalls;
    await tester.tap(find.byTooltip('Back'));
    await settleAsync(tester);
    expect(find.text('Minit'), findsOneWidget);
    expect(env.router.canPop(), isFalse);
    expect(env.playback.stopCalls, greaterThan(prevStops));

    // Drill back in (even from Search tab) -> Record -> Stop & Save -> System back
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    env.rec.simulateSavedMeeting(demoId);
    await settleAsync(tester);
    expect(find.text('Audio timeline'), findsOneWidget);
    expect(env.router.canPop(), isTrue);

    // Android system back pops Detail to Library (NOT Search, NOT exiting!)
    final popped = await env.router.routerDelegate.popRoute();
    await settleAsync(tester);
    expect(popped, isTrue);
    expect(find.text('Minit'), findsOneWidget);
    expect(env.router.canPop(), isFalse);

    // System back from root Library returns false -> Android exits app normally
    final rootPopped = await env.router.routerDelegate.popRoute();
    expect(rootPopped, isFalse);
  });

  testWidgets('Search and Settings non-root screens have leading Back arrows to Library',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(db.close));

    final env = await pumpApp(tester, db: db);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Search titles & transcripts'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Minit'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Minit'), findsOneWidget);
    expect(env.router.canPop(), isFalse);
  });

  testWidgets('Notification-tap & deep-link cold entry keep Library underneath',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    var dbClosed = false;
    addTearDown(() async {
      if (!dbClosed) {
        await tester.runAsync(db.close);
      }
    });
    await tester.runAsync(() async {
      await DemoMeetingSeed.insertDemoMeeting(db);
    });

    // 1. Cold start from foreground-service notification route (/library/record)
    final envNotif = await pumpApp(
      tester,
      db: db,
      initialLocation: '/library/record',
    );
    expect(find.text('Start recording'), findsOneWidget);
    expect(envNotif.router.canPop(), isTrue);
    await tester.tap(find.byTooltip('Back'));
    await settleAsync(tester);
    expect(find.text('Minit'), findsOneWidget);
    expect(envNotif.router.canPop(), isFalse);

    // 2. Notification tap while app is alive on Settings -> lands on Library > Record
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    envNotif.rec.simulateNotificationTap();
    await settleAsync(tester);
    expect(find.text('Stop and save'), findsOneWidget);
    expect(envNotif.router.canPop(), isTrue);

    // While recording is active, tapping Back shows warning dialog
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Recording in progress'), findsOneWidget);
    await tester.tap(find.text('Keep recording & leave'));
    await settleAsync(tester);
    expect(find.text('Minit'), findsOneWidget);

    // Cleanly dispose first container & DB before testing cold deep-link tree.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(db.close);
    dbClosed = true;

    // 3. Cold deep-link /meeting/:id redirects to /library/meeting/:id with Library underneath
    final db2 = AppDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(db2.close));
    late final String deepDemoId;
    await tester.runAsync(() async {
      deepDemoId = await DemoMeetingSeed.insertDemoMeeting(db2);
    });
    final envDeep = await pumpApp(
      tester,
      db: db2,
      initialLocation: '/meeting/$deepDemoId',
    );
    expect(envDeep.router.canPop(), isTrue);
    await tester.tap(find.byTooltip('Back'));
    await settleAsync(tester);
    expect(find.text('Minit'), findsOneWidget);
    expect(envDeep.router.canPop(), isFalse);
  });
}
