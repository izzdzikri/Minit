import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../models/recording_item.dart';
import '../providers/app_providers.dart';
import '../router/app_router.dart';
import '../services/app_settings.dart';
import '../services/permissions_service.dart';
import '../theme/minute_tokens.dart';
import '../widgets/error_state.dart';
import '../widgets/minute_back_button.dart';
import '../widgets/offline_banner.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_header.dart';
import '../widgets/status_chip.dart';
import '../widgets/text_prompt_dialog.dart';
import '../widgets/waveform_view.dart';

const _languageOptions = <(String code, String label)>[
  ('ms', 'Malay (default)'),
  ('en', 'English'),
  ('auto', 'Auto'),
];

/// Full recording studio screen with live 10 Hz waveform, timer, marker tool,
/// Force record toggle, consent reminder, and predictive back guard.
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _glossaryController;
  String? _selectedLanguage;
  bool _syncedInitialSettings = false;

  @override
  void initState() {
    super.initState();
    final currentRec = ref.read(recordingControllerProvider);
    _titleController = TextEditingController(text: currentRec.title);
    _glossaryController = TextEditingController(text: currentRec.glossary);
    if (currentRec.isActive) {
      _selectedLanguage = normalizeLanguageCode(currentRec.language);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(recordingControllerProvider.notifier).refreshDeviceStatus(),
      );
      unawaited(
        ref.read(recordingControllerProvider.notifier).syncWithRunningService(),
      );
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _glossaryController.dispose();
    super.dispose();
  }

  Future<bool> _ensureSessionConsent() async {
    if (ref.read(sessionConsentProvider)) return true;

    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Before you record'),
        content: const Text(
          'Let everyone in the room or call know you are recording audio. '
          'Audio stays on your device in this version.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue recording'),
          ),
        ],
      ),
    );

    if (agreed == true) {
      ref.read(sessionConsentProvider.notifier).markConsented();
      return true;
    }
    return false;
  }

  Future<void> _onStartPressed() async {
    final consented = await _ensureSessionConsent();
    if (!consented || !mounted) return;

    final settings =
        ref.read(settingsControllerProvider).value ?? const AppSettings();
    final lang = _selectedLanguage ?? settings.defaultLanguage;
    await ref.read(recordingControllerProvider.notifier).startRecording(
          context: context,
          title: _titleController.text,
          language: lang,
          forceMode: settings.forceRecordMode,
        );
  }

  Future<void> _addMarkerWithOptionalLabel() async {
    final label = await showTextPromptDialog(
      context: context,
      title: 'Flag moment',
      hintText: 'Optional note (e.g. Exam deadline)',
      confirmLabel: 'Add marker',
      allowEmpty: true,
      emptyFallback: 'Important moment',
    );
    if (label == null || !mounted) return;
    ref.read(recordingControllerProvider.notifier).addMarker(label);
  }

  void _leaveRecordRoute() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/library');
    }
  }

  void _handleBackPressed() {
    if (ref.read(recordingControllerProvider).isActive) {
      unawaited(_confirmBackWhileRecording());
      return;
    }
    _leaveRecordRoute();
  }

  Future<void> _confirmBackWhileRecording() async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recording in progress'),
        content: const Text(
          'You can leave this screen and keep recording in the background '
          'using the notification, or stay here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('stay'),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('leave'),
            child: const Text('Keep recording & leave'),
          ),
        ],
      ),
    );

    if (action == 'leave' && mounted) {
      _leaveRecordRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final theme = Theme.of(context);
    final settingsGate = ref.watch(
      settingsControllerProvider.select(
        (s) => (
          isLoading: s.isLoading && !s.hasValue,
          hasError: s.hasError && !s.hasValue,
        ),
      ),
    );

    ref.listen<String?>(
      recordingControllerProvider.select((s) => s.lastSavedMeetingId),
      (prev, savedId) {
        if (savedId != null && savedId != prev && mounted) {
          final router = GoRouter.of(context);
          ref.read(recordingControllerProvider.notifier).clearLastSaved();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            navigateToMeetingOverLibrary(router, savedId);
          });
        }
      },
    );

    ref.listen<String?>(
      settingsControllerProvider.select((s) => s.value?.defaultLanguage),
      (prev, nextDefault) {
        if (!_syncedInitialSettings && nextDefault != null) {
          _syncedInitialSettings = true;
          final rec = ref.read(recordingControllerProvider);
          final nextLang = rec.isActive ? rec.language : nextDefault;
          if (_selectedLanguage != nextLang) {
            setState(() {
              _selectedLanguage = nextLang;
            });
          }
        }
      },
    );

    final initialDefaultLang = ref.read(settingsControllerProvider).value?.defaultLanguage;
    if (!_syncedInitialSettings && initialDefaultLang != null) {
      _syncedInitialSettings = true;
      final rec = ref.read(recordingControllerProvider);
      _selectedLanguage ??= rec.isActive ? rec.language : initialDefaultLang;
    }
    final activeLang = normalizeLanguageCode(
      _selectedLanguage ?? initialDefaultLang ?? 'ms',
    );

    return _RecordPopScope(
      onConfirmLeave: _confirmBackWhileRecording,
      child: Scaffold(
        appBar: _RecordAppBar(onBackPressed: _handleBackPressed),
        body: SafeArea(
          top: false,
          child: settingsGate.isLoading
              ? const Center(child: CircularProgressIndicator())
              : settingsGate.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(MinuteSpacing.md),
                      child: Center(
                        child: ErrorState(
                          message: 'Could not load recorder preferences.',
                          onRetry: () => ref
                              .read(settingsControllerProvider.notifier)
                              .reload(),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(MinuteSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _RecordBanners(),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(MinuteSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: const [
                                  _RecordingStatusHeader(),
                                  SizedBox(height: MinuteSpacing.md),
                                  _RecordingTimerReadout(),
                                  SizedBox(height: MinuteSpacing.md),
                                  _LiveWaveformSlot(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: MinuteSpacing.md),
                          _RecorderActionControls(
                            onStartPressed: _onStartPressed,
                            onAddLabelledMarker: _addMarkerWithOptionalLabel,
                          ),
                          const SizedBox(height: MinuteSpacing.sm),
                          const _ForceRecordToggleCard(),
                          const SizedBox(height: MinuteSpacing.lg),
                          const SectionHeader(title: 'Details'),
                          _DetailsCard(
                            titleController: _titleController,
                            glossaryController: _glossaryController,
                            activeLang: activeLang,
                            onLanguageSelected: (code) {
                              final norm = normalizeLanguageCode(code);
                              setState(() {
                                _selectedLanguage = norm;
                              });
                              ref
                                  .read(recordingControllerProvider.notifier)
                                  .setDraftLanguage(norm);
                            },
                            theme: theme,
                            colors: c,
                          ),
                          const _MarkersSection(),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}

class _RecordPopScope extends ConsumerWidget {
  const _RecordPopScope({
    required this.onConfirmLeave,
    required this.child,
  });

  final Future<void> Function() onConfirmLeave;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(
      recordingControllerProvider.select((s) => s.isActive),
    );
    return PopScope(
      canPop: !isActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isActive) {
          unawaited(onConfirmLeave());
        }
      },
      child: child,
    );
  }
}

class _RecordAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _RecordAppBar({required this.onBackPressed});

  final VoidCallback onBackPressed;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barState = ref.watch(
      recordingControllerProvider.select(
        (s) => (
          showForceChip: s.isForceMode && s.isActive,
          oemInfo: s.oemInfo?.needsAggressiveBackgroundHelp == true
              ? s.oemInfo
              : null,
        ),
      ),
    );

    return AppBar(
      leading: MinuteBackButton(onPressedOverride: onBackPressed),
      title: Row(
        children: [
          const Flexible(
            child: Text(
              'Record',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (barState.showForceChip) ...[
            const SizedBox(width: MinuteSpacing.sm),
            const StatusChip(
              label: 'FORCE',
              tone: StatusChipTone.accent,
              semanticLabel: 'Force record mode active',
            ),
          ],
        ],
      ),
      actions: [
        if (barState.oemInfo != null)
          IconButton(
            tooltip: 'Background recording help',
            onPressed: () {
              unawaited(
                PermissionsService.openAutoStartHelpDialog(
                  context,
                  barState.oemInfo!,
                ),
              );
            },
            icon: const Icon(Icons.help_outline),
          ),
      ],
    );
  }
}

class _RecordBanners extends ConsumerWidget {
  const _RecordBanners();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityOnlineProvider);
    final banner = ref.watch(
      recordingControllerProvider.select(
        (s) => (
          oem: (s.oemInfo?.needsAggressiveBackgroundHelp == true &&
                  !s.ignoringBatteryOpt)
              ? s.oemInfo
              : null,
          statusMessage: s.statusMessage,
          messageLevel: s.messageLevel,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isOnline)
          const OfflineBanner(
            message: 'Offline — recording continues locally on your phone.',
          ),
        if (banner.oem != null) ...[
          _OemWarningBanner(
            oem: banner.oem!,
            onFixBattery: () async {
              await PermissionsService.requestBatteryOptimizationExemption(
                context,
              );
              await ref
                  .read(recordingControllerProvider.notifier)
                  .refreshDeviceStatus();
            },
            onShowHelp: () {
              unawaited(
                PermissionsService.openAutoStartHelpDialog(
                  context,
                  banner.oem!,
                ),
              );
            },
          ),
          const SizedBox(height: MinuteSpacing.sm),
        ],
        if (banner.statusMessage != null &&
            banner.statusMessage!.trim().isNotEmpty) ...[
          _StatusBanner(
            message: banner.statusMessage!,
            level: banner.messageLevel,
            onDismiss: () =>
                ref.read(recordingControllerProvider.notifier).clearMessage(),
          ),
          const SizedBox(height: MinuteSpacing.sm),
        ],
      ],
    );
  }
}

class _RecordingStatusHeader extends ConsumerWidget {
  const _RecordingStatusHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final header = ref.watch(
      recordingControllerProvider.select(
        (s) => (
          status: s.status,
          isForceMode: s.isForceMode,
          freeGbTenths: s.freeBytes > 0
              ? (s.freeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)
              : null,
        ),
      ),
    );

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: MinuteSpacing.sm,
      runSpacing: MinuteSpacing.xs,
      children: [
        StatusChip(
          label: switch (header.status) {
            RecorderStatus.idle => 'Ready',
            RecorderStatus.recording =>
              header.isForceMode ? 'FORCE recording' : 'Recording',
            RecorderStatus.paused => 'Paused',
            RecorderStatus.finalizing => 'Saving audio',
          },
          tone: switch (header.status) {
            RecorderStatus.recording => StatusChipTone.danger,
            RecorderStatus.paused => StatusChipTone.warning,
            RecorderStatus.finalizing => StatusChipTone.accent,
            RecorderStatus.idle => StatusChipTone.neutral,
          },
        ),
        if (header.freeGbTenths != null)
          Text(
            '${header.freeGbTenths} GB free',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _RecordingTimerReadout extends ConsumerWidget {
  const _RecordingTimerReadout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timerState = ref.watch(
      recordingControllerProvider.select(
        (s) => (
          elapsedSeconds: s.elapsed.inSeconds,
          isActive: s.isActive,
          segmentCount: s.segmentCount,
        ),
      ),
    );
    final elapsedText =
        TimelineMarker.formatHms(timerState.elapsedSeconds * 1000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Recording timer $elapsedText',
          child: Center(
            child: Text(
              elapsedText,
              style: theme.textTheme.displayMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: MinuteSpacing.xs),
        Center(
          child: Text(
            timerState.isActive
                ? '16 kHz mono AAC (48 kbps)  •  ${timerState.segmentCount} segment(s)'
                : '16 kHz mono AAC (48 kbps)  •  Saved continuously every 30s',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _LiveWaveformSlot extends ConsumerWidget {
  const _LiveWaveformSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waveform = ref.read(liveWaveformControllerProvider);
    return LiveWaveformView(
      controller: waveform,
      height: 96,
    );
  }
}

class _RecorderActionControls extends ConsumerWidget {
  const _RecorderActionControls({
    required this.onStartPressed,
    required this.onAddLabelledMarker,
  });

  final VoidCallback onStartPressed;
  final VoidCallback onAddLabelledMarker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rec = ref.watch(
      recordingControllerProvider.select(
        (s) => (
          isActive: s.isActive,
          status: s.status,
        ),
      ),
    );
    final isFinalizing = rec.status == RecorderStatus.finalizing;

    if (!rec.isActive) {
      return PrimaryButton(
        label: 'Start recording',
        icon: Icons.mic,
        isLoading: isFinalizing,
        onPressed: onStartPressed,
      );
    }

    return Wrap(
      spacing: MinuteSpacing.sm,
      runSpacing: MinuteSpacing.sm,
      children: [
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label: 'Stop and save',
            icon: Icons.stop,
            isDestructive: true,
            isLoading: isFinalizing,
            onPressed: isFinalizing
                ? null
                : () =>
                    ref.read(recordingControllerProvider.notifier).stopRecording(),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: OutlinedButton.icon(
              onPressed: isFinalizing
                  ? null
                  : () => ref
                      .read(recordingControllerProvider.notifier)
                      .togglePauseResume(),
              icon: Icon(
                rec.status == RecorderStatus.paused
                    ? Icons.play_arrow
                    : Icons.pause,
              ),
              label: Text(
                rec.status == RecorderStatus.paused
                    ? 'Resume recording'
                    : 'Pause recording',
              ),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: OutlinedButton.icon(
                  onPressed: isFinalizing
                      ? null
                      : () => ref
                          .read(recordingControllerProvider.notifier)
                          .addMarker(),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Mark moment'),
                ),
              ),
            ),
            const SizedBox(width: MinuteSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: OutlinedButton(
                onPressed: isFinalizing ? null : onAddLabelledMarker,
                child: const Tooltip(
                  message: 'Add labelled marker',
                  child: Icon(Icons.edit_note),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ForceRecordToggleCard extends ConsumerWidget {
  const _ForceRecordToggleCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forceRecordMode = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.forceRecordMode ?? false,
      ),
    );

    return Card(
      child: SwitchListTile(
        value: forceRecordMode,
        onChanged: (enabled) async {
          final error = await ref
              .read(settingsControllerProvider.notifier)
              .setForceRecordMode(enabled);
          if (error != null && context.mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(error)));
          }
        },
        title: const Text('Force record (never pause)'),
        subtitle: const Text(
          'Keeps recording through calls, other audio apps, and headset unplugs. Logs silence windows >5s.',
        ),
      ),
    );
  }
}

class _DetailsCard extends ConsumerWidget {
  const _DetailsCard({
    required this.titleController,
    required this.glossaryController,
    required this.activeLang,
    required this.onLanguageSelected,
    required this.theme,
    required this.colors,
  });

  final TextEditingController titleController;
  final TextEditingController glossaryController;
  final String activeLang;
  final ValueChanged<String> onLanguageSelected;
  final ThemeData theme;
  final MinuteColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFinalizing = ref.watch(
      recordingControllerProvider.select(
        (s) => s.status == RecorderStatus.finalizing,
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MinuteSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: titleController,
              enabled: !isFinalizing,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) => ref
                  .read(recordingControllerProvider.notifier)
                  .setDraftTitle(value),
              decoration: const InputDecoration(
                labelText: 'Meeting title (optional)',
                hintText: 'e.g. Week 7 Lab or Product Sync',
              ),
            ),
            const SizedBox(height: MinuteSpacing.md),
            Text(
              'Spoken language',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: MinuteSpacing.sm),
            Wrap(
              spacing: MinuteSpacing.sm,
              runSpacing: MinuteSpacing.xs,
              children: [
                for (final option in _languageOptions)
                  ChoiceChip(
                    label: Text(option.$2),
                    selected: activeLang == option.$1,
                    onSelected: isFinalizing
                        ? null
                        : (_) => onLanguageSelected(option.$1),
                  ),
              ],
            ),
            if (activeLang == 'auto') ...[
              const SizedBox(height: MinuteSpacing.sm),
              Container(
                padding: const EdgeInsets.all(MinuteSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.warningSubtle,
                  borderRadius: BorderRadius.circular(MinuteRadii.sm),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: colors.warning,
                    ),
                    const SizedBox(width: MinuteSpacing.sm),
                    Expanded(
                      child: Text(
                        'Auto detects from the first 30 seconds only.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: MinuteSpacing.md),
            TextField(
              controller: glossaryController,
              enabled: !isFinalizing,
              maxLines: null,
              minLines: 1,
              onChanged: (value) => ref
                  .read(recordingControllerProvider.notifier)
                  .setDraftGlossary(value),
              decoration: const InputDecoration(
                labelText: 'Glossary hints (optional)',
                hintText: 'Override Settings default (e.g. ChatGPT, benchmark, names)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkersSection extends ConsumerWidget {
  const _MarkersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final markers = ref.watch(
      recordingControllerProvider.select((s) => s.markers),
    );
    if (markers.isEmpty) {
      return const SizedBox.shrink();
    }

    final c = context.minuteColors;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: MinuteSpacing.lg),
        SectionHeader(title: 'Markers (${markers.length})'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(MinuteSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < markers.length; i++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        markers[i].type == MarkerType.marker
                            ? Icons.flag_outlined
                            : Icons.info_outline,
                        size: 18,
                        color: c.accentText,
                      ),
                      const SizedBox(width: MinuteSpacing.sm),
                      Expanded(
                        child: Text(
                          markers[i].displayLabel,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  if (i < markers.length - 1)
                    const Divider(height: MinuteSpacing.md),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OemWarningBanner extends StatelessWidget {
  const _OemWarningBanner({
    required this.oem,
    required this.onFixBattery,
    required this.onShowHelp,
  });

  final OemDeviceInfo oem;
  final VoidCallback onFixBattery;
  final VoidCallback onShowHelp;

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final theme = Theme.of(context);
    return Card(
      color: c.warningSubtle,
      child: Padding(
        padding: const EdgeInsets.all(MinuteSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.battery_alert, color: c.warning, size: 20),
                const SizedBox(width: MinuteSpacing.sm),
                Expanded(
                  child: Text(
                    'Keep recording alive on ${oem.brand}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: c.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MinuteSpacing.xs),
            Text(
              'Disable battery optimization so the OS does not stop long background recordings when the screen is locked.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: MinuteSpacing.sm),
            Wrap(
              spacing: MinuteSpacing.sm,
              runSpacing: MinuteSpacing.xs,
              children: [
                FilledButton(
                  onPressed: onFixBattery,
                  child: const Text('Allow unrestricted'),
                ),
                OutlinedButton(
                  onPressed: onShowHelp,
                  child: const Text('Autostart steps'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.level,
    required this.onDismiss,
  });

  final String message;
  final String level;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final theme = Theme.of(context);
    final (Color bg, Color fg) = switch (level) {
      'error' => (c.dangerSubtle, c.danger),
      'warning' => (c.warningSubtle, c.warning),
      _ => (c.surfaceSubtle, c.textPrimary),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MinuteSpacing.md,
          vertical: MinuteSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(MinuteRadii.card),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(color: fg),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss message',
              onPressed: onDismiss,
              icon: Icon(Icons.close, size: 18, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
