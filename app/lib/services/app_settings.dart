import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// How Normal mode behaves when another app (like YouTube) plays audio.
enum OtherAppAudioBehavior {
  keepRecording,
  pause,
}

/// Persisted user preferences shared between the UI and foreground service.
class AppSettings {
  const AppSettings({
    this.themePreference = ThemeMode.system,
    this.defaultLanguage = 'auto',
    this.otherAppAudioBehavior = OtherAppAudioBehavior.keepRecording,
    this.forceRecordMode = false,
  });

  final ThemeMode themePreference;
  final String defaultLanguage;
  final OtherAppAudioBehavior otherAppAudioBehavior;
  final bool forceRecordMode;

  AppSettings copyWith({
    ThemeMode? themePreference,
    String? defaultLanguage,
    OtherAppAudioBehavior? otherAppAudioBehavior,
    bool? forceRecordMode,
  }) {
    return AppSettings(
      themePreference: themePreference ?? this.themePreference,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      otherAppAudioBehavior:
          otherAppAudioBehavior ?? this.otherAppAudioBehavior,
      forceRecordMode: forceRecordMode ?? this.forceRecordMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'themePreference': themePreference.name,
        'defaultLanguage': defaultLanguage,
        'otherAppAudioBehavior': otherAppAudioBehavior.name,
        'forceRecordMode': forceRecordMode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final themeName = json['themePreference']?.toString();
    final behaviorName = json['otherAppAudioBehavior']?.toString();
    return AppSettings(
      themePreference: ThemeMode.values.firstWhere(
        (e) => e.name == themeName,
        orElse: () => ThemeMode.system,
      ),
      defaultLanguage: json['defaultLanguage'] as String? ?? 'auto',
      otherAppAudioBehavior: OtherAppAudioBehavior.values.firstWhere(
        (e) => e.name == behaviorName,
        orElse: () => OtherAppAudioBehavior.keepRecording,
      ),
      forceRecordMode: json['forceRecordMode'] as bool? ??
          json['forceRecord'] as bool? ??
          false,
    );
  }
}

class AppSettingsStorage {
  AppSettingsStorage._();

  @visibleForTesting
  static Directory? testBaseDirectory;

  static Future<void> _saveQueue = Future<void>.value();
  static int _tmpSeq = 0;

  static Future<File> _settingsFile() async {
    final docs = testBaseDirectory ?? await getApplicationDocumentsDirectory();
    return File(p.join(docs.path, 'minit_settings.json'));
  }

  static Future<AppSettings> load() async {
    try {
      final file = await _settingsFile();
      if (!file.existsSync()) return const AppSettings();
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AppSettings.fromJson(decoded);
      }
    } catch (_) {}
    return const AppSettings();
  }

  /// Persists [settings] off the synchronous UI call stack using an ordered
  /// async write queue so rapid toggle taps never race on temp files.
  static Future<void> save(AppSettings settings) {
    final next = _saveQueue.catchError((_) {}).then((_) async {
      final file = await _settingsFile();
      await file.parent.create(recursive: true);
      final seq = _tmpSeq++;
      final tmp = File('${file.path}.$seq.tmp');
      await tmp.writeAsString(jsonEncode(settings.toJson()));
      await tmp.rename(file.path);
    });
    _saveQueue = next;
    return next;
  }
}
