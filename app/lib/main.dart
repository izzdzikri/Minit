import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'providers/app_providers.dart';
import 'router/app_router.dart';
import 'theme/minute_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'minit_recording_channel',
      channelName: 'Minit Recording',
      channelDescription:
          'Keeps audio recording active while the screen is locked or app is in background.',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      onlyAlertOnce: true,
      showWhen: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(1000),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: true,
      allowWifiLock: false,
      allowAutoRestart: false,
      stopWithTask: false,
    ),
  );

  runApp(
    const ProviderScope(
      child: MinitApp(),
    ),
  );
}

/// Root Minit widget wiring theme tokens, system/user theme mode, and GoRouter.
class MinitApp extends ConsumerWidget {
  const MinitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.themePreference ?? ThemeMode.system,
      ),
    );
    final router = ref.watch(appRouterProvider);

    ref.listen<int>(
      recordingControllerProvider.select((s) => s.openRecordRequestSeq),
      (prev, next) {
        if (next > (prev ?? 0)) {
          navigateToRecordOverLibrary(router);
        }
      },
    );

    return MaterialApp.router(
      title: 'Minit',
      debugShowCheckedModeBanner: false,
      theme: MinuteTheme.light(),
      darkTheme: MinuteTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
