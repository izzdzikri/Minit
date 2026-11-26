import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../providers/app_providers.dart';
import '../services/app_settings.dart';
import '../services/backend_api_client.dart';
import '../services/permissions_service.dart';
import '../services/recording_storage.dart';
import '../theme/minute_tokens.dart';
import '../widgets/error_state.dart';
import '../widgets/minute_back_button.dart';
import '../widgets/offline_banner.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton_loader.dart';

final storageUsageBytesProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(meetingsProvider);
  return RecordingStorage.getTotalStorageBytes();
});

const _languageNames = <(String code, String label)>[
  ('ms', 'Malay (default)'),
  ('en', 'English'),
  ('auto', 'Auto'),
];

/// App settings screen: transcription server & secure API token, upload toggles,
/// global glossary hints, theme, default language, interruption rules, and storage.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _serverUrlController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _glossaryController = TextEditingController();

  bool _controllersSeeded = false;
  bool _obscureToken = true;
  bool _testingConnection = false;
  String? _connectionStatusMsg;
  bool _connectionStatusOk = false;
  bool _deletingAll = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadToken());
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _tokenController.dispose();
    _glossaryController.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    try {
      final token = await ref.read(tokenStorageProvider).readToken();
      if (!mounted) return;
      if (token != null && token.isNotEmpty) {
        _tokenController.text = token;
      }
    } catch (_) {}
  }

  void _seedFromSettings(AppSettings settings) {
    if (_controllersSeeded) return;
    _controllersSeeded = true;
    _serverUrlController.text = settings.serverUrl;
    _glossaryController.text = settings.defaultGlossary;
  }

  Future<void> _saveServerFields() async {
    final notifier = ref.read(settingsControllerProvider.notifier);
    await notifier.setServerUrl(_serverUrlController.text);
    await ref.read(tokenStorageProvider).writeToken(_tokenController.text);
  }

  Future<void> _testConnection() async {
    setState(() {
      _testingConnection = true;
      _connectionStatusMsg = null;
    });
    try {
      await _saveServerFields();
      final url = AppSettings.normalizeServerUrl(_serverUrlController.text);
      final token = _tokenController.text.trim();
      final health = await ref.read(backendApiClientProvider).testHealth(
            serverUrl: url,
            token: token,
          );
      if (!mounted) return;
      setState(() {
        _connectionStatusOk = true;
        _connectionStatusMsg =
            'Connected (${health.model} ${health.computeType}, default ${health.defaultLanguage}).';
      });
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() {
        _connectionStatusOk = false;
        _connectionStatusMsg = e.userMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _connectionStatusOk = false;
        _connectionStatusMsg = 'Could not reach the configured server.';
      });
    } finally {
      if (mounted) {
        setState(() => _testingConnection = false);
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _confirmDeleteAllData() async {
    final rec = ref.read(recordingControllerProvider);
    if (rec.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stop the active recording before deleting all data.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all local data?'),
        content: const Text(
          'This permanently removes every recording file, waveform, '
          'transcript, and note stored on this phone. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _deletingAll = true);
    try {
      await ref.read(meetingsProvider.notifier).deleteAllData();
      ref.invalidate(storageUsageBytesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All local meetings and audio deleted.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete all local data.')),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final theme = Theme.of(context);
    final isOnline = ref.watch(connectivityOnlineProvider);
    final settingsAsync = ref.watch(settingsControllerProvider);
    final storageAsync = ref.watch(storageUsageBytesProvider);
    final oemBattery = ref.watch(
      recordingControllerProvider.select(
        (s) => (oemInfo: s.oemInfo, ignoringBatteryOpt: s.ignoringBatteryOpt),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: const MinuteBackButton(),
        title: Semantics(header: true, child: const Text('Settings')),
      ),
      body: SafeArea(
        top: false,
        child: settingsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(MinuteSpacing.md),
            child: SkeletonLoader(itemCount: 3),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(MinuteSpacing.md),
            child: Center(
              child: ErrorState(
                message: 'Could not load settings from local storage.',
                onRetry: () =>
                    ref.read(settingsControllerProvider.notifier).reload(),
              ),
            ),
          ),
          data: (settings) {
            _seedFromSettings(settings);
            final activeLang = normalizeLanguageCode(settings.defaultLanguage);
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                MinuteSpacing.md,
                MinuteSpacing.sm,
                MinuteSpacing.md,
                108,
              ),
              children: [
                if (!isOnline) const OfflineBanner(),

                const SectionHeader(title: 'Transcription server'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(MinuteSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _serverUrlController,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          onChanged: (value) => ref
                              .read(settingsControllerProvider.notifier)
                              .setServerUrl(value),
                          decoration: const InputDecoration(
                            labelText: 'Server URL',
                            hintText: 'http://localhost:8000',
                            helperText:
                                'Use http://localhost:8000 with adb reverse in debug, or https:// in release.',
                          ),
                        ),
                        const SizedBox(height: MinuteSpacing.md),
                        TextField(
                          controller: _tokenController,
                          obscureText: _obscureToken,
                          autocorrect: false,
                          enableSuggestions: false,
                          onChanged: (value) => unawaited(
                            ref.read(tokenStorageProvider).writeToken(value),
                          ),
                          decoration: InputDecoration(
                            labelText: 'API token (stored securely)',
                            hintText: 'Bearer token from backend .env',
                            suffixIcon: IconButton(
                              tooltip:
                                  _obscureToken ? 'Show token' : 'Hide token',
                              onPressed: () => setState(
                                () => _obscureToken = !_obscureToken,
                              ),
                              icon: Icon(
                                _obscureToken
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: MinuteSpacing.md),
                        PrimaryButton(
                          label: 'Test connection',
                          icon: Icons.cloud_done_outlined,
                          isLoading: _testingConnection,
                          onPressed: _testConnection,
                        ),
                        if (_connectionStatusMsg != null) ...[
                          const SizedBox(height: MinuteSpacing.sm),
                          Container(
                            padding: const EdgeInsets.all(MinuteSpacing.sm),
                            decoration: BoxDecoration(
                              color: _connectionStatusOk
                                  ? c.successSubtle
                                  : c.dangerSubtle,
                              borderRadius:
                                  BorderRadius.circular(MinuteRadii.sm),
                            ),
                            child: Text(
                              _connectionStatusMsg!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    _connectionStatusOk ? c.success : c.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: MinuteSpacing.lg),

                const SectionHeader(title: 'Uploads & vocabulary'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(MinuteSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Upload automatically'),
                          subtitle: const Text(
                            'Queue finished recordings for transcription.',
                          ),
                          value: settings.autoUpload,
                          onChanged: (value) => ref
                              .read(settingsControllerProvider.notifier)
                              .setAutoUpload(value),
                        ),
                        const Divider(height: MinuteSpacing.md),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Wi-Fi only'),
                          subtitle: const Text(
                            'Pause uploads on mobile data and resume on Wi-Fi.',
                          ),
                          value: settings.wifiOnlyUpload,
                          onChanged: (value) => ref
                              .read(settingsControllerProvider.notifier)
                              .setWifiOnlyUpload(value),
                        ),
                        const Divider(height: MinuteSpacing.md),
                        TextField(
                          controller: _glossaryController,
                          maxLines: null,
                          minLines: 2,
                          onChanged: (value) => ref
                              .read(settingsControllerProvider.notifier)
                              .setDefaultGlossary(value),
                          decoration: const InputDecoration(
                            labelText: 'Default glossary (optional)',
                            hintText:
                                'ChatGPT, benchmark, decision tree, synthetic data',
                            helperText:
                                'Comma-separated tech terms & names passed as Whisper vocabulary hints.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: MinuteSpacing.lg),

                const SectionHeader(title: 'Appearance'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(MinuteSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Theme', style: theme.textTheme.titleSmall),
                        const SizedBox(height: MinuteSpacing.sm),
                        Wrap(
                          spacing: MinuteSpacing.sm,
                          runSpacing: MinuteSpacing.xs,
                          children: [
                            ChoiceChip(
                              label: const Text('Follow system'),
                              selected:
                                  settings.themePreference == ThemeMode.system,
                              onSelected: (_) => ref
                                  .read(settingsControllerProvider.notifier)
                                  .setThemePreference(ThemeMode.system),
                            ),
                            ChoiceChip(
                              label: const Text('Light'),
                              selected:
                                  settings.themePreference == ThemeMode.light,
                              onSelected: (_) => ref
                                  .read(settingsControllerProvider.notifier)
                                  .setThemePreference(ThemeMode.light),
                            ),
                            ChoiceChip(
                              label: const Text('Dark'),
                              selected:
                                  settings.themePreference == ThemeMode.dark,
                              onSelected: (_) => ref
                                  .read(settingsControllerProvider.notifier)
                                  .setThemePreference(ThemeMode.dark),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: MinuteSpacing.lg),

                const SectionHeader(title: 'Recording defaults'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(MinuteSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Default language',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: MinuteSpacing.sm),
                        Wrap(
                          spacing: MinuteSpacing.sm,
                          runSpacing: MinuteSpacing.xs,
                          children: [
                            for (final lang in _languageNames)
                              ChoiceChip(
                                label: Text(lang.$2),
                                selected: activeLang == lang.$1,
                                onSelected: (_) => ref
                                    .read(settingsControllerProvider.notifier)
                                    .setDefaultLanguage(lang.$1),
                              ),
                          ],
                        ),
                        if (activeLang == 'auto') ...[
                          const SizedBox(height: MinuteSpacing.sm),
                          Container(
                            padding: const EdgeInsets.all(MinuteSpacing.sm),
                            decoration: BoxDecoration(
                              color: c.warningSubtle,
                              borderRadius:
                                  BorderRadius.circular(MinuteRadii.sm),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                  color: c.warning,
                                ),
                                const SizedBox(width: MinuteSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Auto detects from the first 30 seconds only.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: c.warning,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Divider(height: MinuteSpacing.lg),
                        Text(
                          'When another app plays audio',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: MinuteSpacing.xs),
                        Text(
                          'Applies in Normal mode. Phone calls pause recording and auto-resume after the call ends.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: MinuteSpacing.sm),
                        Wrap(
                          spacing: MinuteSpacing.sm,
                          runSpacing: MinuteSpacing.xs,
                          children: [
                            ChoiceChip(
                              label: const Text('Keep recording (default)'),
                              selected: settings.otherAppAudioBehavior ==
                                  OtherAppAudioBehavior.keepRecording,
                              onSelected: (_) => ref
                                  .read(settingsControllerProvider.notifier)
                                  .setOtherAppAudioBehavior(
                                    OtherAppAudioBehavior.keepRecording,
                                  ),
                            ),
                            ChoiceChip(
                              label: const Text('Pause recording'),
                              selected: settings.otherAppAudioBehavior ==
                                  OtherAppAudioBehavior.pause,
                              onSelected: (_) => ref
                                  .read(settingsControllerProvider.notifier)
                                  .setOtherAppAudioBehavior(
                                    OtherAppAudioBehavior.pause,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: MinuteSpacing.lg),

                if (oemBattery.oemInfo != null) ...[
                  const SectionHeader(title: 'Background reliability'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(MinuteSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Device: ${oemBattery.oemInfo!.brand} (${oemBattery.oemInfo!.model})',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: MinuteSpacing.xs),
                          Text(
                            oemBattery.ignoringBatteryOpt
                                ? 'Unrestricted battery permission is enabled.'
                                : 'Battery optimization may stop long background recordings.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: oemBattery.ignoringBatteryOpt
                                  ? c.success
                                  : c.warning,
                            ),
                          ),
                          const SizedBox(height: MinuteSpacing.sm),
                          Wrap(
                            spacing: MinuteSpacing.sm,
                            runSpacing: MinuteSpacing.xs,
                            children: [
                              OutlinedButton(
                                onPressed: () async {
                                  await PermissionsService
                                      .requestBatteryOptimizationExemption(
                                    context,
                                  );
                                  await ref
                                      .read(
                                          recordingControllerProvider.notifier)
                                      .refreshDeviceStatus();
                                },
                                child: const Text('Battery settings'),
                              ),
                              OutlinedButton(
                                onPressed: () {
                                  unawaited(
                                    PermissionsService.openAutoStartHelpDialog(
                                      context,
                                      oemBattery.oemInfo!,
                                    ),
                                  );
                                },
                                child: const Text('Autostart guide'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: MinuteSpacing.lg),
                ],

                const SectionHeader(title: 'Storage on device'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(MinuteSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Local storage used',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  storageAsync.when(
                                    loading: () => Text(
                                      'Calculating...',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    error: (_, _) => Text(
                                      'Unavailable',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    data: (bytes) => Text(
                                      _formatBytes(bytes),
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        color: c.accentText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Refresh storage usage',
                              onPressed: () =>
                                  ref.invalidate(storageUsageBytesProvider),
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                        const SizedBox(height: MinuteSpacing.md),
                        PrimaryButton(
                          label: 'Delete all data',
                          icon: Icons.delete_forever_outlined,
                          isDestructive: true,
                          isLoading: _deletingAll,
                          onPressed: _confirmDeleteAllData,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
