import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:material_ui/material_ui.dart';

import 'screens/spike_home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'minute_recording_channel',
      channelName: 'Minute Recording',
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

  runApp(const MinuteSpikeApp());
}

class MinuteSpikeApp extends StatelessWidget {
  const MinuteSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minute',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0F766E),
      ),
      home: const SpikeHomeScreen(),
    );
  }
}
