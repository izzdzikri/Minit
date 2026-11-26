import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:minit/data/database/app_database.dart';
import 'package:minit/main.dart';
import 'package:minit/providers/app_providers.dart';
import 'package:minit/router/app_router.dart';
import 'package:minit/services/app_settings.dart';
import 'package:minit/services/recording_storage.dart';
import 'package:minit/widgets/waveform_view.dart';

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

  void simulateRecordingActive({bool isForceMode = false}) {
    state = state.copyWith(
      status: RecorderStatus.recording,
      isForceMode: isForceMode,
      elapsed: const Duration(seconds: 3),
    );
  }

  void simulateBatchedSamples(List<double> samples, {required int elapsedMs}) {
    ref.read(liveWaveformControllerProvider).addSamples(
          samples,
          elapsedMs: elapsedMs,
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UI responsiveness & ring buffer optimizations', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('minit_perf_test_');
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

    test('LiveWaveformController ring buffer caps capacity and orders samples',
        () {
      final controller = LiveWaveformController(capacity: 4);
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.addSamples([0.1, 0.2, 0.3], elapsedMs: 300);
      expect(controller.length, 3);
      expect(controller.levels, [0.1, 0.2, 0.3]);
      expect(controller.latestElapsedMs, 300);
      expect(notifications, 1);

      controller.addSamples([0.4, 0.5, 0.6], elapsedMs: 600);
      expect(controller.length, 4);
      expect(controller.levels, [0.3, 0.4, 0.5, 0.6]);
      expect(controller.currentLevel, 0.6);
      expect(controller.latestElapsedMs, 600);
      expect(notifications, 2);
    });

    testWidgets(
      'Force record switch flips on the first frame before persistence finishes and does not rebuild root shell',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(db.close));

        final saveCompleter = Completer<void>();
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            connectivityOnlineProvider.overrideWith(_OnlineTrueNotifier.new),
            recordingControllerProvider
                .overrideWith(_TestRecordingController.new),
            settingsPersistProvider.overrideWithValue((_) => saveCompleter.future),
          ],
        );
        addTearDown(container.dispose);

        final router = container.read(appRouterProvider);
        navigateToRecordOverLibrary(router);

        var rootLibraryBuilds = 0;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: Builder(
              builder: (context) {
                return Consumer(
                  builder: (context, ref, _) {
                    final themeMode = ref.watch(
                      settingsControllerProvider.select(
                        (s) => s.value?.themePreference ?? ThemeMode.system,
                      ),
                    );
                    if (themeMode == ThemeMode.system) {
                      rootLibraryBuilds++;
                    }
                    return const MinitApp();
                  },
                );
              },
            ),
          ),
        );

        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pumpAndSettle();

        final initialRootBuilds = rootLibraryBuilds;
        final switchFinder = find.byType(Switch);
        expect(switchFinder, findsOneWidget);
        expect(tester.widget<Switch>(switchFinder).value, isFalse);

        await tester.tap(switchFinder);
        // Single frame pump BEFORE saveCompleter completes: must flip optimistically!
        await tester.pump();
        expect(tester.widget<Switch>(switchFinder).value, isTrue);
        expect(rootLibraryBuilds, initialRootBuilds);

        // Sending batched waveform levels must not fail or trigger root rebuilds.
        final rec = container.read(recordingControllerProvider.notifier)
            as _TestRecordingController;
        rec.simulateBatchedSamples([0.2, 0.5, 0.8], elapsedMs: 1200);
        await tester.pump();
        expect(rootLibraryBuilds, initialRootBuilds);

        saveCompleter.complete();
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(switchFinder).value, isTrue);
      },
    );

    testWidgets(
      'Force record switch reverts and shows SnackBar when persistence or service sync fails',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(db.close));

        final saveCompleter = Completer<void>();
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            connectivityOnlineProvider.overrideWith(_OnlineTrueNotifier.new),
            recordingControllerProvider
                .overrideWith(_TestRecordingController.new),
            settingsPersistProvider
                .overrideWithValue((_) => saveCompleter.future),
            forceModeServiceSyncProvider.overrideWithValue(
              (_) => Future<void>.error(StateError('service unavailable')),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MinitApp(),
          ),
        );
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pumpAndSettle();

        navigateToRecordOverLibrary(container.read(appRouterProvider));
        await tester.pumpAndSettle();

        final rec = container.read(recordingControllerProvider.notifier)
            as _TestRecordingController;
        rec.simulateRecordingActive(isForceMode: false);
        await tester.pump();

        final switchFinder = find.byType(Switch);
        expect(tester.widget<Switch>(switchFinder).value, isFalse);
        expect(find.text('FORCE'), findsNothing);

        await tester.tap(switchFinder);
        await tester.pump();

        // Optimistically ON immediately before background persist/sync finishes.
        expect(tester.widget<Switch>(switchFinder).value, isTrue);
        expect(find.text('FORCE'), findsOneWidget);

        // Complete persist -> service sync fails -> both switch & FORCE revert.
        saveCompleter.complete();
        await tester.pumpAndSettle();

        expect(tester.widget<Switch>(switchFinder).value, isFalse);
        expect(find.text('FORCE'), findsNothing);
        expect(find.text('Could not update Force record mode.'), findsOneWidget);
      },
    );
  });
}
