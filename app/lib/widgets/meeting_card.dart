import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../data/database/app_database.dart';
import '../models/recording_item.dart';
import '../theme/minute_tokens.dart';
import 'status_chip.dart';
import 'tag_chip.dart';
import 'waveform_view.dart';

class MeetingCard extends StatelessWidget {
  const MeetingCard({
    super.key,
    required this.item,
    required this.peaks,
    required this.onTap,
    this.onRetry,
  });

  static final DateFormat _cardDateFormat = DateFormat('d MMM, HH:mm');

  final MeetingListItem item;
  final Uint8List? peaks;
  final VoidCallback onTap;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final theme = Theme.of(context);
    final m = item.meeting;
    final dateText = _cardDateFormat.format(m.createdAt.toLocal());
    final durationText = TimelineMarker.formatTimestamp(m.durationMs);

    return Semantics(
      button: true,
      label:
          '${m.title}, $dateText, duration $durationText, status ${m.status}',
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MinuteRadii.card),
          child: Padding(
            padding: const EdgeInsets.all(MinuteSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.title,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: MinuteSpacing.xs),
                          Text(
                            '$dateText  •  $durationText',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: MinuteSpacing.sm),
                    MiniWaveformThumbnail(peaks: peaks),
                  ],
                ),
                if (item.summarySnippet != null &&
                    item.summarySnippet!.trim().isNotEmpty) ...[
                  const SizedBox(height: MinuteSpacing.sm),
                  Text(
                    item.summarySnippet!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ] else if (m.note != null && m.note!.trim().isNotEmpty) ...[
                  const SizedBox(height: MinuteSpacing.sm),
                  Text(
                    m.note!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ] else if (m.status.toLowerCase() != 'ready' &&
                    m.statusMessage != null &&
                    m.statusMessage!.trim().isNotEmpty) ...[
                  const SizedBox(height: MinuteSpacing.sm),
                  Text(
                    m.statusMessage!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: m.status.toLowerCase() == 'failed'
                          ? c.danger
                          : c.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: MinuteSpacing.sm),
                Wrap(
                  spacing: MinuteSpacing.xs,
                  runSpacing: MinuteSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusChip.fromMeetingStatus(
                      m.status,
                      progressPercent: m.status.toLowerCase() == 'uploading'
                          ? m.uploadProgress
                          : null,
                    ),
                    if (m.status.toLowerCase() == 'failed' && onRetry != null)
                      ActionChip(
                        avatar: Icon(Icons.refresh, size: 15, color: c.danger),
                        label: Text(
                          'Retry',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: c.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: c.dangerSubtle,
                        side: BorderSide(color: c.danger.withValues(alpha: 0.4)),
                        visualDensity: VisualDensity.compact,
                        onPressed: onRetry,
                      ),
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
                    for (final tag in item.tags) TagChip(label: tag.name),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
