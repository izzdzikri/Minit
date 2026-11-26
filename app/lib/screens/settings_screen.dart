import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../providers/app_providers.dart';
import '../services/app_settings.dart';
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
  ('auto', 'Auto-detect'),
  ('mixed', 'Mixed (English / Malay)'),
  ('en', 'English'),
  ('ms', 'Bahasa Melayu'),
];

/// App settings screen: theme, default language, interruption rules,
/// OEM battery reliability help, storage usage, and destructive clear-all.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _deletingAll = false;

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
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                MinuteSpacing.md,
                MinuteSpacing.sm,
                MinuteSpacing.md,
                108,
              ),
              children: [
                if (!isOnline) const OfflineBanner(),

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
                                selected: settings.defaultLanguage == lang.$1,
                                onSelected: (_) => ref
                                    .read(settingsControllerProvider.notifier)
                                    .setDefaultLanguage(lang.$1),
                              ),
                          ],
                        ),
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
