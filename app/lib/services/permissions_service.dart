import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import 'native_bridge.dart';

class OemDeviceInfo {
  const OemDeviceInfo({
    required this.brand,
    required this.manufacturer,
    required this.model,
    required this.androidRelease,
    required this.sdkInt,
    required this.needsAggressiveBackgroundHelp,
    required this.helpTitle,
    required this.helpSteps,
  });

  final String brand;
  final String manufacturer;
  final String model;
  final String androidRelease;
  final int sdkInt;
  final bool needsAggressiveBackgroundHelp;
  final String helpTitle;
  final List<String> helpSteps;
}

class PermissionsService {
  PermissionsService._();

  static const _restrictedOems = {
    'xiaomi',
    'redmi',
    'poco',
    'oppo',
    'realme',
    'oneplus',
    'vivo',
    'iqoo',
    'samsung',
  };

  static Future<OemDeviceInfo> getOemDeviceInfo() async {
    if (!Platform.isAndroid) {
      return const OemDeviceInfo(
        brand: 'Other',
        manufacturer: 'Other',
        model: 'Unknown',
        androidRelease: '',
        sdkInt: 0,
        needsAggressiveBackgroundHelp: false,
        helpTitle: '',
        helpSteps: [],
      );
    }

    final info = await DeviceInfoPlugin().androidInfo;
    final brand = info.brand;
    final manufacturer = info.manufacturer;
    final brandLower = brand.toLowerCase();
    final mfgLower = manufacturer.toLowerCase();
    final needsHelp = _restrictedOems.contains(brandLower) ||
        _restrictedOems.contains(mfgLower);

    final steps = _buildOemSteps(brandLower, mfgLower);
    return OemDeviceInfo(
      brand: brand,
      manufacturer: manufacturer,
      model: info.model,
      androidRelease: info.version.release,
      sdkInt: info.version.sdkInt,
      needsAggressiveBackgroundHelp: needsHelp,
      helpTitle: '$brand ($manufacturer) Background Recording Setup',
      helpSteps: steps,
    );
  }

  static List<String> _buildOemSteps(String brand, String mfg) {
    if (brand.contains('vivo') ||
        brand.contains('iqoo') ||
        mfg.contains('vivo')) {
      return const [
        '1. Allow "Don\'t optimize" / Unrestricted battery usage when prompted.',
        '2. Open Settings > Battery > Background power consumption management > Minit > High background power consumption (or Unrestricted).',
        '3. Enable Autostart / Background app launch if listed in App Info or iManager.',
        '4. Open Recent Apps, swipe down or tap the menu on Minit, and tap Lock so the system RAM cleaner cannot kill an active recording.',
      ];
    }
    if (brand.contains('xiaomi') ||
        brand.contains('redmi') ||
        brand.contains('poco') ||
        mfg.contains('xiaomi')) {
      return const [
        '1. Allow "No restrictions" in Battery Saver for Minit.',
        '2. Enable Autostart under Settings > Apps > Manage apps > Minit > Autostart.',
        '3. Lock Minit in Recent Apps during long 30+ minute recordings.',
      ];
    }
    if (brand.contains('oppo') ||
        brand.contains('realme') ||
        brand.contains('oneplus') ||
        mfg.contains('oppo')) {
      return const [
        '1. Set Battery usage to "Allow background activity" and disable optimization.',
        '2. Enable "Allow auto-launch" under App Management > Minit.',
        '3. Lock Minit in Recent Apps.',
      ];
    }
    if (brand.contains('samsung') || mfg.contains('samsung')) {
      return const [
        '1. Set Battery to "Unrestricted" under App Info > Battery > Minit.',
        '2. Make sure Minit is NOT in Settings > Battery > Background usage limits > Sleeping / Deep sleeping apps.',
      ];
    }
    return const [
      'Set Battery usage to Unrestricted so Android does not pause background recording.',
    ];
  }

  /// Requests `RECORD_AUDIO` and `POST_NOTIFICATIONS` (Android 13+) in context,
  /// explaining why they are needed and opening app settings on permanent denial.
  static Future<bool> ensureRecordingPermissions(BuildContext context) async {
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      if (micStatus.isPermanentlyDenied) {
        if (context.mounted) {
          await _showSettingsDialog(
            context,
            title: 'Microphone permission required',
            message:
                'Microphone access was permanently denied. Open App Settings and enable Microphone so Minit can record meetings.',
          );
        }
        return false;
      }

      if (!context.mounted) return false;
      final proceed = await _showRationaleDialog(
        context,
        title: 'Allow microphone access',
        message:
            'Minit records meetings and lectures in 16 kHz mono AAC audio while the screen is locked.',
        confirmLabel: 'Continue',
      );
      if (!proceed) return false;

      micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (micStatus.isPermanentlyDenied && context.mounted) {
          await _showSettingsDialog(
            context,
            title: 'Microphone permission required',
            message:
                'Please allow Microphone access in App Settings to start recording.',
          );
        }
        return false;
      }
    }

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        var notifStatus = await Permission.notification.status;
        if (!notifStatus.isGranted) {
          if (notifStatus.isPermanentlyDenied) {
            if (context.mounted) {
              await _showSettingsDialog(
                context,
                title: 'Notification permission required',
                message:
                    'Android 13+ needs notification permission so you can see the active recording timer and Stop button on the lock screen. Please enable Notifications in App Settings.',
              );
            }
            return false;
          }

          if (!context.mounted) return false;
          final proceed = await _showRationaleDialog(
            context,
            title: 'Allow recording notification',
            message:
                'Minit uses a persistent foreground notification with a Stop button while recording in the background or with the screen locked.',
            confirmLabel: 'Allow',
          );
          if (!proceed) return false;

          notifStatus = await Permission.notification.request();
          if (!notifStatus.isGranted) {
            if (notifStatus.isPermanentlyDenied && context.mounted) {
              await _showSettingsDialog(
                context,
                title: 'Notification permission required',
                message:
                    'Notifications are permanently denied. Please enable Notifications in App Settings so the foreground recording service stays visible.',
              );
            }
            return false;
          }
        }
      }
    }

    return true;
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    return FlutterForegroundTask.isIgnoringBatteryOptimizations;
  }

  static Future<bool> requestBatteryOptimizationExemption(
    BuildContext context,
  ) async {
    if (await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      return true;
    }
    if (!context.mounted) return false;

    final confirmed = await _showRationaleDialog(
      context,
      title: 'Exclude Minit from battery optimization',
      message:
          'Long 30+ minute recordings with the screen off can be killed by battery savers unless Minit is excluded from battery optimization.',
      confirmLabel: 'Exclude now',
    );
    if (!confirmed) return false;

    final granted =
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    if (!granted && context.mounted) {
      await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
    }
    return FlutterForegroundTask.isIgnoringBatteryOptimizations;
  }

  static Future<void> openAutoStartHelpDialog(
    BuildContext context,
    OemDeviceInfo oem,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(oem.helpTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Detected ${oem.brand} (${oem.model}) on Android ${oem.androidRelease}. '
                'To keep 30+ minute recordings alive with the screen locked:',
              ),
              const SizedBox(height: 12),
              for (final step in oem.helpSteps) ...[
                Text(step),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await NativeBridge.openAutoStartSettings();
            },
            child: const Text('Open device settings'),
          ),
        ],
      ),
    );
  }

  static Future<bool> _showRationaleDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<void> _showSettingsDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await openAppSettings();
            },
            child: const Text('Open App Settings'),
          ),
        ],
      ),
    );
  }
}
