import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database/app_database.dart';
import '../models/recording_item.dart';
import '../providers/app_providers.dart';
import '../services/markdown_exporter.dart';
import '../services/playback_controller.dart';
import '../theme/minute_tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/minute_back_button.dart';
import '../widgets/offline_banner.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/status_chip.dart';
import '../widgets/tag_chip.dart';
import '../widgets/text_prompt_dialog.dart';
import '../widgets/waveform_view.dart';

enum _DetailTab { summary, transcript }

/// Meeting Detail view with editable title & tags, full replay waveform,
/// docked audio mini-player, Summary & Transcript tabs, inline editing,
/// and "Copy for AI" Markdown export.
class MeetingDetailScreen extends ConsumerStatefulWidget {
  const MeetingDetailScreen({
    super.key,
    required this.meetingId,
    this.initialSeekSeconds,
  });

  final String meetingId;
  final int? initialSeekSeconds;

  @override
  ConsumerState<MeetingDetailScreen> createState() =>
      _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends ConsumerState<MeetingDetailScreen> {
  _DetailTab _selectedTab = _DetailTab.summary;
  bool _miniPlayerExpanded = false;
  String? _loadedAudioForId;
  int? _appliedInitialSeekSec;
  late final PlaybackController _playback;

  @override
  void initState() {
    super.initState();
    _playback = ref.read(playbackControllerProvider);
    if (widget.initialSeekSeconds != null) {
      _selectedTab = _DetailTab.transcript;
    }
  }

  @override
  void dispose() {
    unawaited(_playback.stop());
    super.dispose();
  }

  void _stopPlaybackSync() {
    unawaited(_playback.stop());
  }

  void _syncPlaybackForMeeting(MeetingDetailData detail) {
    final m = detail.meeting;
    final seekChanged = widget.initialSeekSeconds != null &&
        widget.initialSeekSeconds != _appliedInitialSeekSec;

    if (_loadedAudioForId == m.id && !seekChanged) return;

    _loadedAudioForId = m.id;
    _appliedInitialSeekSec = widget.initialSeekSeconds;

    final initialSeek = widget.initialSeekSeconds != null
        ? Duration(seconds: widget.initialSeekSeconds!)
        : null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(playbackControllerProvider).loadMeetingAudio(
              meetingId: m.id,
              filePath: m.audioPath,
              fallbackDuration: Duration(milliseconds: m.durationMs),
              initialSeek: initialSeek,
            ),
      );
    });
  }

  Future<void> _editTitle(MeetingDetailData detail) async {
    final newTitle = await showTextPromptDialog(
      context: context,
      title: 'Rename meeting',
      initialValue: detail.meeting.title,
      labelText: 'Title',
      confirmLabel: 'Save',
    );
    if (newTitle == null || !mounted) return;

    await ref
        .read(meetingRepositoryProvider)
        .renameMeeting(detail.meeting.id, newTitle);
    ref.invalidate(meetingDetailProvider(widget.meetingId));
    await ref.read(meetingsProvider.notifier).refresh();
  }

  Future<void> _addTagDialog(MeetingDetailData detail) async {
    final newTag = await showTextPromptDialog(
      context: context,
      title: 'Add tag',
      labelText: 'Tag name',
      hintText: 'e.g. lecture, sprint, cs301',
      confirmLabel: 'Add',
    );
    if (newTag == null || !mounted) return;

    await ref.read(meetingRepositoryProvider).addTag(detail.meeting.id, newTag);
    ref.invalidate(meetingDetailProvider(widget.meetingId));
    await ref.read(meetingsProvider.notifier).refresh();
  }

  Future<void> _removeTag(String tagId) async {
    await ref
        .read(meetingRepositoryProvider)
        .removeTag(widget.meetingId, tagId);
    ref.invalidate(meetingDetailProvider(widget.meetingId));
    await ref.read(meetingsProvider.notifier).refresh();
  }

  Future<void> _toggleActionItem(ActionItem item) async {
    await ref
        .read(meetingRepositoryProvider)
        .toggleActionItem(item.id, !item.done);
    ref.invalidate(meetingDetailProvider(widget.meetingId));
  }

  Future<void> _editTranscriptSegment(TranscriptSegmentWithSpeaker item) async {
    final updated = await showTextPromptDialog(
      context: context,
      title: item.speaker?.displayName ?? 'Edit transcript line',
      initialValue: item.segment.textContent,
      labelText: 'Transcript text',
      confirmLabel: 'Save edit',
      maxLines: 6,
      minLines: 3,
    );
    if (updated == null || !mounted) return;

    await ref
        .read(meetingRepositoryProvider)
        .updateSegmentText(item.segment.id, updated);
    ref.invalidate(meetingDetailProvider(widget.meetingId));
  }

  Future<void> _openExportSheet(MeetingDetailData detail) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ExportBottomSheet(detail: detail),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final theme = Theme.of(context);
    final detailAsync = ref.watch(meetingDetailProvider(widget.meetingId));
    final playback = ref.watch(playbackControllerProvider);
    final isOnline = ref.watch(connectivityOnlineProvider);

    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: MinuteBackButton(onBeforeNavigate: _stopPlaybackSync),
          title: const Text('Meeting'),
        ),
        body: const Padding(
          padding: EdgeInsets.all(MinuteSpacing.md),
          child: SkeletonLoader(itemCount: 3),
        ),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(
          leading: MinuteBackButton(onBeforeNavigate: _stopPlaybackSync),
          title: const Text('Meeting'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(MinuteSpacing.md),
          child: Center(
            child: ErrorState(
              message: 'Could not load this meeting from local storage.',
              onRetry: () =>
                  ref.invalidate(meetingDetailProvider(widget.meetingId)),
            ),
          ),
        ),
      ),
      data: (detail) {
        if (detail == null) {
          return Scaffold(
            appBar: AppBar(
              leading: MinuteBackButton(onBeforeNavigate: _stopPlaybackSync),
              title: const Text('Meeting'),
            ),
            body: Padding(
              padding: const EdgeInsets.all(MinuteSpacing.md),
              child: Center(
                child: EmptyState(
                  icon: Icons.folder_off_outlined,
                  title: 'Meeting not found',
                  message: 'This meeting may have been deleted from your phone.',
                  actionLabel: 'Back to Library',
                  onAction: () {
                    _stopPlaybackSync();
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/library');
                    }
                  },
                ),
              ),
            ),
          );
        }

        _syncPlaybackForMeeting(detail);
        final peaksAsync =
            ref.watch(meetingPeaksProvider(detail.meeting.peaksPath));
        final m = detail.meeting;
        final dateText =
            DateFormat('d MMM yyyy, HH:mm').format(m.createdAt.toLocal());
        final durationText = TimelineMarker.formatTimestamp(m.durationMs);

        return Scaffold(
          appBar: AppBar(
            leading: MinuteBackButton(onBeforeNavigate: _stopPlaybackSync),
            title: Text(
              m.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                tooltip: 'Export or Copy for AI',
                onPressed: () => _openExportSheet(detail),
                icon: const Icon(Icons.ios_share_outlined),
              ),
            ],
          ),
          bottomNavigationBar: _MiniPlayerBar(
            playback: playback,
            meeting: m,
            expanded: _miniPlayerExpanded,
            onToggleExpanded: () => setState(() {
              _miniPlayerExpanded = !_miniPlayerExpanded;
            }),
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.all(MinuteSpacing.md),
              children: [
                if (!isOnline) const OfflineBanner(),
                // Title, metadata, tags
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(MinuteSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Semantics(
                                button: true,
                                label: 'Meeting title ${m.title}. Tap to rename.',
                                child: InkWell(
                                  onTap: () => _editTitle(detail),
                                  borderRadius:
                                      BorderRadius.circular(MinuteRadii.sm),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      m.title,
                                      style: theme.textTheme.headlineSmall,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Rename meeting',
                              onPressed: () => _editTitle(detail),
                              icon: Icon(
                                Icons.edit_outlined,
                                size: 20,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MinuteSpacing.xs),
                        Text(
                          '$dateText  •  $durationText  •  ${m.language.toUpperCase()}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: MinuteSpacing.sm),
                        Wrap(
                          spacing: MinuteSpacing.xs,
                          runSpacing: MinuteSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StatusChip.fromMeetingStatus(m.status),
                            if (m.isForceMode)
                              const StatusChip(
                                label: 'FORCE',
                                tone: StatusChipTone.accent,
                              ),
                            if (m.isPartial)
                              const StatusChip(
                                label: 'Partial',
                                tone: StatusChipTone.warning,
                              ),
                            for (final tag in detail.tags)
                              TagChip(
                                label: tag.name,
                                onDelete: () => _removeTag(tag.id),
                              ),
                            Semantics(
                              button: true,
                              label: 'Add tag',
                              child: ActionChip(
                                avatar: const Icon(Icons.add, size: 16),
                                label: const Text('Tag'),
                                onPressed: () => _addTagDialog(detail),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MinuteSpacing.md),
                        Wrap(
                          spacing: MinuteSpacing.sm,
                          runSpacing: MinuteSpacing.sm,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _openExportSheet(detail),
                              icon: const Icon(Icons.copy_all_outlined, size: 18),
                              label: const Text('Copy for AI / Export'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: MinuteSpacing.md),

                // Replay Waveform Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(MinuteSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader(title: 'Audio timeline'),
                        ListenableBuilder(
                          listenable: playback,
                          builder: (context, _) {
                            final totalDur = playback.currentMeetingId == m.id &&
                                    playback.duration > Duration.zero
                                ? playback.duration
                                : Duration(milliseconds: m.durationMs);
                            final pos = playback.currentMeetingId == m.id
                                ? playback.position
                                : Duration.zero;
                            return ReplayWaveformView(
                              peaks: peaksAsync.value,
                              position: pos,
                              duration: totalDur,
                              markers: detail.markers,
                              onSeek: (target) async {
                                if (playback.currentMeetingId != m.id) {
                                  await playback.loadMeetingAudio(
                                    meetingId: m.id,
                                    filePath: m.audioPath,
                                    fallbackDuration: totalDur,
                                    initialSeek: target,
                                  );
                                } else {
                                  await playback.seek(target);
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: MinuteSpacing.md),

                // Summary / Transcript switcher
                Row(
                  children: [
                    Expanded(
                      child: _TabPillButton(
                        label: 'Summary',
                        selected: _selectedTab == _DetailTab.summary,
                        onTap: () =>
                            setState(() => _selectedTab = _DetailTab.summary),
                      ),
                    ),
                    const SizedBox(width: MinuteSpacing.sm),
                    Expanded(
                      child: _TabPillButton(
                        label: 'Transcript',
                        selected: _selectedTab == _DetailTab.transcript,
                        onTap: () => setState(
                          () => _selectedTab = _DetailTab.transcript,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MinuteSpacing.md),

                if (_selectedTab == _DetailTab.summary)
                  _SummaryTabContent(
                    detail: detail,
                    onToggleAction: _toggleActionItem,
                  )
                else
                  _TranscriptTabContent(
                    detail: detail,
                    playback: playback,
                    onSeek: (sec) => playback.seek(
                      Duration(milliseconds: (sec * 1000).round()),
                    ),
                    onEditSegment: _editTranscriptSegment,
                  ),
                const SizedBox(height: MinuteSpacing.lg),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TabPillButton extends StatelessWidget {
  const _TabPillButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label tab',
      child: Material(
        color: selected ? c.accent : c.surface,
        borderRadius: BorderRadius.circular(MinuteRadii.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MinuteRadii.card),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: MinuteSpacing.md,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MinuteRadii.card),
              border: Border.all(
                color: selected ? c.accent : c.border,
              ),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? c.accentForeground : c.textPrimary,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryTabContent extends StatelessWidget {
  const _SummaryTabContent({
    required this.detail,
    required this.onToggleAction,
  });

  final MeetingDetailData detail;
  final ValueChanged<ActionItem> onToggleAction;

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final theme = Theme.of(context);
    final summary = detail.summary;

    if (summary == null && detail.actionItems.isEmpty) {
      return const EmptyState(
        icon: Icons.summarize_outlined,
        title: 'No AI summary yet',
        message:
            'This audio is saved on your phone. AI transcription and structured summaries arrive in a later phase.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary != null && summary.row.summary.trim().isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(MinuteSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Overview'),
                  Text(
                    summary.row.summary.trim(),
                    style: MinuteTypography.editorialSummary(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MinuteSpacing.md),
        ],
        if (summary != null && summary.keyPoints.isNotEmpty) ...[
          _BulletCard(title: 'Key points', items: summary.keyPoints),
          const SizedBox(height: MinuteSpacing.md),
        ],
        if (summary != null && summary.decisions.isNotEmpty) ...[
          _BulletCard(title: 'Decisions', items: summary.decisions),
          const SizedBox(height: MinuteSpacing.md),
        ],
        if (detail.actionItems.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(MinuteSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Action items'),
                  for (final item in detail.actionItems)
                    Semantics(
                      toggled: item.done,
                      label: '${item.task}, owner ${item.owner}',
                      child: InkWell(
                        onTap: () => onToggleAction(item),
                        borderRadius: BorderRadius.circular(MinuteRadii.sm),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: MinuteSpacing.xs,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: item.done,
                                  onChanged: (_) => onToggleAction(item),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.task,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            decoration: item.done
                                                ? TextDecoration.lineThrough
                                                : null,
                                            color: item.done
                                                ? c.textMuted
                                                : c.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: MinuteSpacing.xs,
                                          runSpacing: MinuteSpacing.xs,
                                          children: [
                                            StatusChip(
                                              label: item.owner,
                                              tone: StatusChipTone.neutral,
                                            ),
                                            if (item.dueDate != null &&
                                                item.dueDate!
                                                    .trim()
                                                    .isNotEmpty)
                                              StatusChip(
                                                label: 'Due ${item.dueDate}',
                                                tone: StatusChipTone.warning,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MinuteSpacing.md),
        ],
        if (summary != null && summary.openQuestions.isNotEmpty)
          _BulletCard(title: 'Open questions', items: summary.openQuestions),
      ],
    );
  }
}

class _BulletCard extends StatelessWidget {
  const _BulletCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MinuteSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: title),
            for (var i = 0; i < items.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 11, right: 10),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      items[i],
                      style: MinuteTypography.editorialBody(context),
                    ),
                  ),
                ],
              ),
              if (i < items.length - 1)
                const SizedBox(height: MinuteSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _TranscriptTabContent extends StatelessWidget {
  const _TranscriptTabContent({
    required this.detail,
    required this.playback,
    required this.onSeek,
    required this.onEditSegment,
  });

  final MeetingDetailData detail;
  final PlaybackController playback;
  final ValueChanged<double> onSeek;
  final ValueChanged<TranscriptSegmentWithSpeaker> onEditSegment;

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final theme = Theme.of(context);

    if (detail.segments.isEmpty && detail.markers.isEmpty) {
      return const EmptyState(
        icon: Icons.notes_outlined,
        title: 'No transcript yet',
        message:
            'Your audio file and waveform are ready locally. Transcript segments will appear once speech-to-text is enabled.',
      );
    }

    final timelineEntries = <({double sortSec, Widget widget})>[];

    for (final entry in detail.segments) {
      timelineEntries.add((
        sortSec: entry.segment.startSec,
        widget: ListenableBuilder(
          listenable: playback,
          builder: (context, _) {
            final currentSec =
                playback.currentMeetingId == detail.meeting.id
                    ? playback.position.inMilliseconds / 1000.0
                    : -1.0;
            final isPlayingHere = currentSec >= entry.segment.startSec &&
                currentSec < entry.segment.endSec;

            final speakerName =
                entry.speaker?.displayName ?? 'Speaker';
            final initials = _initials(speakerName);
            final ts = TimelineMarker.formatTimestamp(
              (entry.segment.startSec * 1000).round(),
            );

            return Container(
              margin: const EdgeInsets.only(bottom: MinuteSpacing.sm),
              decoration: BoxDecoration(
                color: isPlayingHere ? c.accentSubtle.withValues(alpha: 0.45) : c.surface,
                borderRadius: BorderRadius.circular(MinuteRadii.card),
                border: Border.all(
                  color: isPlayingHere ? c.accent : c.border,
                  width: isPlayingHere ? 1.5 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(MinuteSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: c.surfaceSubtle,
                          child: Text(
                            initials,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: c.accentText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: MinuteSpacing.sm),
                        Expanded(
                          child: Text(
                            speakerName,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Jump to $ts',
                          child: InkWell(
                            onTap: () => onSeek(entry.segment.startSec),
                            borderRadius:
                                BorderRadius.circular(MinuteRadii.sm),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: 40,
                                minWidth: 48,
                              ),
                              child: Center(
                                child: Text(
                                  ts,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: c.accentText,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit transcript line',
                          onPressed: () => onEditSegment(entry),
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MinuteSpacing.xs),
                    GestureDetector(
                      onTap: () => onSeek(entry.segment.startSec),
                      child: Text(
                        entry.segment.textContent,
                        style: MinuteTypography.editorialBody(context),
                      ),
                    ),
                    if (entry.segment.edited) ...[
                      const SizedBox(height: MinuteSpacing.xs),
                      Text(
                        'Edited',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ));
    }

    for (final marker in detail.markers) {
      timelineEntries.add((
        sortSec: marker.startMs / 1000.0,
        widget: Semantics(
          button: true,
          label: 'Jump to marker: ${marker.displayLabel}',
          child: InkWell(
            onTap: () => onSeek(marker.startMs / 1000.0),
            borderRadius: BorderRadius.circular(MinuteRadii.card),
            child: Container(
              margin: const EdgeInsets.only(bottom: MinuteSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: MinuteSpacing.md,
                vertical: MinuteSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: c.surfaceSubtle,
                borderRadius: BorderRadius.circular(MinuteRadii.card),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  Icon(
                    marker.type == MarkerType.marker
                        ? Icons.flag_outlined
                        : Icons.info_outline,
                    size: 18,
                    color: c.accentText,
                  ),
                  const SizedBox(width: MinuteSpacing.sm),
                  Expanded(
                    child: Text(
                      marker.displayLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
    }

    timelineEntries.sort((a, b) => a.sortSec.compareTo(b.sortSec));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final item in timelineEntries) item.widget],
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'SP';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _MiniPlayerBar extends StatelessWidget {
  const _MiniPlayerBar({
    required this.playback,
    required this.meeting,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final PlaybackController playback;
  final Meeting meeting;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final isActiveForThis = playback.currentMeetingId == meeting.id;
        final dur = isActiveForThis && playback.duration > Duration.zero
            ? playback.duration
            : Duration(milliseconds: meeting.durationMs);
        final pos = isActiveForThis ? playback.position : Duration.zero;
        final isPlaying = isActiveForThis && playback.isPlaying;
        final hasLocalAudio = meeting.audioPath != null &&
            meeting.audioPath!.isNotEmpty &&
            File(meeting.audioPath!).existsSync();

        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.border, width: 1)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MinuteSpacing.md,
                vertical: MinuteSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Semantics(
                        button: true,
                        label: isPlaying ? 'Pause audio' : 'Play audio',
                        child: IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: c.accent,
                            foregroundColor: c.accentForeground,
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: playback.isLoading
                              ? null
                              : () => playback.togglePlay(
                                    meetingId: meeting.id,
                                    filePath: meeting.audioPath,
                                    fallbackDuration: Duration(
                                      milliseconds: meeting.durationMs,
                                    ),
                                  ),
                          icon: playback.isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: c.accentForeground,
                                  ),
                                )
                              : Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                ),
                        ),
                      ),
                      const SizedBox(width: MinuteSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${TimelineMarker.formatTimestamp(pos.inMilliseconds)} / ${TimelineMarker.formatTimestamp(dur.inMilliseconds)}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            if (playback.errorMessage != null &&
                                isActiveForThis)
                              Text(
                                playback.errorMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: c.danger,
                                ),
                              )
                            else if (!hasLocalAudio)
                              Text(
                                'Demo entry — waveform only (no .m4a file)',
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: expanded
                            ? 'Collapse player controls'
                            : 'Expand player controls',
                        onPressed: onToggleExpanded,
                        icon: Icon(
                          expanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                        ),
                      ),
                    ],
                  ),
                  if (expanded) ...[
                    const SizedBox(height: MinuteSpacing.xs),
                    Wrap(
                      spacing: MinuteSpacing.sm,
                      runSpacing: MinuteSpacing.xs,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Back 10 seconds',
                              onPressed: () => playback.skipBy(
                                const Duration(seconds: -10),
                              ),
                              icon: const Icon(Icons.replay_10),
                            ),
                            IconButton(
                              tooltip: 'Forward 10 seconds',
                              onPressed: () => playback.skipBy(
                                const Duration(seconds: 10),
                              ),
                              icon: const Icon(Icons.forward_10),
                            ),
                          ],
                        ),
                        Semantics(
                          button: true,
                          label: 'Playback speed ${playback.speed}x. Tap to cycle.',
                          child: OutlinedButton(
                            onPressed: () {
                              final nextIndex =
                                  (_speeds.indexOf(playback.speed) + 1) %
                                      _speeds.length;
                              unawaited(playback.setSpeed(_speeds[nextIndex]));
                            },
                            child: Text('${playback.speed}x'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExportBottomSheet extends StatefulWidget {
  const _ExportBottomSheet({required this.detail});

  final MeetingDetailData detail;

  @override
  State<_ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<_ExportBottomSheet> {
  ExportMode _mode = ExportMode.fullWithAiPrompt;
  bool _saving = false;

  Future<void> _copyText(String text, {String label = 'Copied to clipboard'}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(label)),
    );
  }

  Future<void> _saveMarkdownFile(String markdown) async {
    setState(() => _saving = true);
    try {
      final docs = await getApplicationDocumentsDirectory();
      final exportsDir = Directory(p.join(docs.path, 'exports'));
      if (!exportsDir.existsSync()) {
        exportsDir.createSync(recursive: true);
      }
      final safeName = widget.detail.meeting.title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      final filename =
          '${safeName.isEmpty ? 'meeting' : safeName}_${widget.detail.meeting.id}.md';
      final file = File(p.join(exportsDir.path, filename));
      await file.writeAsString(markdown, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved $filename'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () {
              unawaited(
                SharePlus.instance.share(
                  ShareParams(
                    files: [XFile(file.path)],
                    subject: widget.detail.meeting.title,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save Markdown file.')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final theme = Theme.of(context);
    final markdown = MarkdownExporter.generate(widget.detail, _mode);
    final tokenCount = MarkdownExporter.estimateTokens(markdown);
    final needsSplit = MarkdownExporter.needsSplitting(markdown);
    final parts = needsSplit
        ? MarkdownExporter.splitIntoParts(markdown)
        : <String>[markdown];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        MinuteSpacing.md,
        MinuteSpacing.md,
        MinuteSpacing.md,
        MinuteSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Export & Copy for AI',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close export options',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: MinuteSpacing.sm),
            Wrap(
              spacing: MinuteSpacing.sm,
              runSpacing: MinuteSpacing.xs,
              children: [
                ChoiceChip(
                  label: const Text('Full + AI prompt'),
                  selected: _mode == ExportMode.fullWithAiPrompt,
                  onSelected: (_) =>
                      setState(() => _mode = ExportMode.fullWithAiPrompt),
                ),
                ChoiceChip(
                  label: const Text('Transcript only'),
                  selected: _mode == ExportMode.transcriptOnly,
                  onSelected: (_) =>
                      setState(() => _mode = ExportMode.transcriptOnly),
                ),
                ChoiceChip(
                  label: const Text('Summary only'),
                  selected: _mode == ExportMode.summaryOnly,
                  onSelected: (_) =>
                      setState(() => _mode = ExportMode.summaryOnly),
                ),
              ],
            ),
            const SizedBox(height: MinuteSpacing.md),
            Container(
              padding: const EdgeInsets.all(MinuteSpacing.md),
              decoration: BoxDecoration(
                color: c.surfaceSubtle,
                borderRadius: BorderRadius.circular(MinuteRadii.card),
                border: Border.all(color: c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated size: ~$tokenCount tokens (${markdown.length} chars)',
                    style: theme.textTheme.titleSmall,
                  ),
                  if (needsSplit) ...[
                    const SizedBox(height: MinuteSpacing.xs),
                    Text(
                      'Over 30,000 tokens — split into ${parts.length} parts so each part fits comfortably in ChatGPT, Claude, or Gemini.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.warning,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: MinuteSpacing.md),
            if (!needsSplit)
              PrimaryButton(
                label: 'Copy for AI',
                icon: Icons.copy,
                onPressed: () => _copyText(
                  markdown,
                  label: 'Copied Markdown (~$tokenCount tokens) to clipboard.',
                ),
              )
            else ...[
              for (var i = 0; i < parts.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: MinuteSpacing.sm),
                  child: PrimaryButton(
                    label:
                        'Copy Part ${i + 1} of ${parts.length} (~${MarkdownExporter.estimateTokens(parts[i])} tokens)',
                    icon: Icons.copy,
                    onPressed: () => _copyText(
                      parts[i],
                      label: 'Copied Part ${i + 1} of ${parts.length}.',
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: MinuteSpacing.sm),
            Wrap(
              spacing: MinuteSpacing.sm,
              runSpacing: MinuteSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _saveMarkdownFile(markdown),
                  icon: const Icon(Icons.save_alt),
                  label: Text(_saving ? 'Saving...' : 'Save as .md'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    unawaited(
                      SharePlus.instance.share(
                        ShareParams(
                          text: markdown,
                          subject: widget.detail.meeting.title,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share text'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
