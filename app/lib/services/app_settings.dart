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

const String defaultMeetingGlossary =
    'ChatGPT, benchmark, decision tree, synthetic data, missing values, imbalance';

const String defaultServerUrl = 'http://localhost:8000';

String normalizeLanguageCode(String? raw) {
  final value = (raw ?? 'ms').trim().toLowerCase();
  return switch (value) {
    'en' => 'en',
    'auto' => 'auto',
    'ms' || 'mixed' => 'ms',
    _ => 'ms',
  };
}

/// Persisted non-secret user preferences shared between UI and recording service.
/// The API bearer token is stored separately in Android Keystore via `SecureTokenStorage`.
class AppSettings {
  const AppSettings({
    this.themePreference = ThemeMode.system,
    this.defaultLanguage = 'ms',
    this.otherAppAudioBehavior = OtherAppAudioBehavior.keepRecording,
    this.forceRecordMode = false,
    this.serverUrl = defaultServerUrl,
    this.wifiOnlyUpload = true,
    this.autoUpload = true,
    this.defaultGlossary = defaultMeetingGlossary,
    this.consentedServerUrl,
  });

  final ThemeMode themePreference;
  final String defaultLanguage;
  final OtherAppAudioBehavior otherAppAudioBehavior;
  final bool forceRecordMode;
  final String serverUrl;
  final bool wifiOnlyUpload;
  final bool autoUpload;
  final String defaultGlossary;
  final String? consentedServerUrl;

  bool hasConsentedFor(String targetServerUrl) {
    final normTarget = normalizeServerUrl(targetServerUrl);
    final consented = consentedServerUrl;
    if (consented == null || consented.isEmpty || normTarget.isEmpty) {
      return false;
    }
    return normalizeServerUrl(consented) == normTarget;
  }

  static String normalizeServerUrl(String raw) {
    var trimmed = raw.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  AppSettings copyWith({
    ThemeMode? themePreference,
    String? defaultLanguage,
    OtherAppAudioBehavior? otherAppAudioBehavior,
    bool? forceRecordMode,
    String? serverUrl,
    bool? wifiOnlyUpload,
    bool? autoUpload,
    String? defaultGlossary,
    String? consentedServerUrl,
    bool clearConsentedServerUrl = false,
  }) {
    return AppSettings(
      themePreference: themePreference ?? this.themePreference,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      otherAppAudioBehavior:
          otherAppAudioBehavior ?? this.otherAppAudioBehavior,
      forceRecordMode: forceRecordMode ?? this.forceRecordMode,
      serverUrl: serverUrl ?? this.serverUrl,
      wifiOnlyUpload: wifiOnlyUpload ?? this.wifiOnlyUpload,
      autoUpload: autoUpload ?? this.autoUpload,
      defaultGlossary: defaultGlossary ?? this.defaultGlossary,
      consentedServerUrl: clearConsentedServerUrl
          ? null
          : (consentedServerUrl ?? this.consentedServerUrl),
    );
  }

  Map<String, dynamic> toJson() => {
        'themePreference': themePreference.name,
        'defaultLanguage': defaultLanguage,
        'otherAppAudioBehavior': otherAppAudioBehavior.name,
        'forceRecordMode': forceRecordMode,
        'serverUrl': serverUrl,
        'wifiOnlyUpload': wifiOnlyUpload,
        'autoUpload': autoUpload,
        'defaultGlossary': defaultGlossary,
        'consentedServerUrl': consentedServerUrl,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final themeName = json['themePreference']?.toString();
    final behaviorName = json['otherAppAudioBehavior']?.toString();
    return AppSettings(
      themePreference: ThemeMode.values.firstWhere(
        (e) => e.name == themeName,
        orElse: () => ThemeMode.system,
      ),
      defaultLanguage: normalizeLanguageCode(
        json['defaultLanguage'] as String?,
      ),
      otherAppAudioBehavior: OtherAppAudioBehavior.values.firstWhere(
        (e) => e.name == behaviorName,
        orElse: () => OtherAppAudioBehavior.keepRecording,
      ),
      forceRecordMode: json['forceRecordMode'] as bool? ??
          json['forceRecord'] as bool? ??
          false,
      serverUrl: (json['serverUrl'] as String?)?.trim().isNotEmpty == true
          ? AppSettings.normalizeServerUrl(json['serverUrl'] as String)
          : defaultServerUrl,
      wifiOnlyUpload: json['wifiOnlyUpload'] as bool? ?? true,
      autoUpload: json['autoUpload'] as bool? ?? true,
      defaultGlossary:
          json['defaultGlossary'] as String? ?? defaultMeetingGlossary,
      consentedServerUrl: json['consentedServerUrl'] as String?,
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
