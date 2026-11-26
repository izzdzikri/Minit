import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/database/app_database.dart';
import '../providers/app_providers.dart';
import '../theme/minute_tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/meeting_card.dart';
import '../widgets/upload_consent_dialog.dart';
import '../widgets/offline_banner.dart';
import '../widgets/skeleton_loader.dart';

/// Home Library screen showing saved local meetings, filter bar, swipe-to-delete
/// with Undo, and dev-only demo seeding.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late final TextEditingController _filterController;

  @override
  void initState() {
    super.initState();
    _filterController = TextEditingController(
      text: ref.read(libraryQueryProvider),
    );
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _handleAddDemo() async {
    try {
      await ref.read(meetingsProvider.notifier).addDemoMeeting();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Added demo Manglish meeting.')),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not add demo meeting.')),
        );
    }
  }

  Future<void> _handleSoftDelete(MeetingListItem item) async {
    final notifier = ref.read(meetingsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final meetingId = item.meeting.id;
    final title = item.meeting.title;

    await notifier.softDelete(meetingId);
    if (!mounted) return;

    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted "$title"'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            unawaited(notifier.restore(meetingId));
          },
        ),
      ),
    );

    final reason = await controller.closed;
    if (reason != SnackBarClosedReason.action) {
      await notifier.commitHardDelete(meetingId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final theme = Theme.of(context);
    final isOnline = ref.watch(connectivityOnlineProvider);
    final query = ref.watch(libraryQueryProvider);
    final meetingsAsync = ref.watch(meetingsProvider);

    ref.listen<AsyncValue<List<MeetingListItem>>>(meetingsProvider, (_, next) {
      if (next.hasValue) {
        final msg = ref.read(meetingsProvider.notifier).takeRecoveryMessage();
        if (msg != null && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg)),
            );
          });
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: const Text('Minit'),
        ),
        actions: [
          if (!kReleaseMode)
            Padding(
              padding: const EdgeInsets.only(right: MinuteSpacing.sm),
              child: Semantics(
                button: true,
                label: 'Add demo meeting for testing',
                child: OutlinedButton.icon(
                  onPressed: _handleAddDemo,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add demo'),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MinuteSpacing.md,
                MinuteSpacing.sm,
                MinuteSpacing.md,
                MinuteSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isOnline) const OfflineBanner(),
                  Semantics(
                    textField: true,
                    label: 'Filter meetings by title',
                    child: TextField(
                      controller: _filterController,
                      onChanged: (value) {
                        ref
                            .read(libraryQueryProvider.notifier)
                            .setQuery(value);
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Filter by title...',
                        prefixIcon: const Icon(Icons.filter_list),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                tooltip: 'Clear filter',
                                onPressed: () {
                                  _filterController.clear();
                                  ref
                                      .read(libraryQueryProvider.notifier)
                                      .setQuery('');
                                },
                                icon: const Icon(Icons.close),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: meetingsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(MinuteSpacing.md),
                  child: SkeletonLoader(itemCount: 4),
                ),
                error: (_, _) => Padding(
                  padding: const EdgeInsets.all(MinuteSpacing.md),
                  child: Center(
                    child: ErrorState(
                      message:
                          'Could not load your saved meetings from device storage.',
                      onRetry: () =>
                          ref.read(meetingsProvider.notifier).refresh(),
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                        MinuteSpacing.md,
                        MinuteSpacing.md,
                        MinuteSpacing.md,
                        108,
                      ),
                      children: [
                        if (query.trim().isNotEmpty)
                          EmptyState(
                            icon: Icons.search_off,
                            title: 'No matching meetings',
                            message:
                                'No meetings matched "$query". Clear the filter or search inside transcripts.',
                            actionLabel: 'Clear filter',
                            onAction: () {
                              _filterController.clear();
                              ref
                                  .read(libraryQueryProvider.notifier)
                                  .setQuery('');
                            },
                          )
                        else ...[
                          EmptyState(
                            icon: Icons.mic_none,
                            title: 'No meetings yet',
                            message:
                                'Tap Record below to capture clear meeting or lecture audio on your phone.',
                            actionLabel: 'Record your first meeting',
                            onAction: () => context.push('/record'),
                          ),
                          if (!kReleaseMode) ...[
                            const SizedBox(height: MinuteSpacing.md),
                            Center(
                              child: OutlinedButton.icon(
                                onPressed: _handleAddDemo,
                                icon: const Icon(Icons.auto_stories_outlined),
                                label: const Text('Add demo meeting'),
                              ),
                            ),
                          ],
                        ],
                      ],
                    );
                  }

                  return RefreshIndicator(
                    color: c.accent,
                    onRefresh: () =>
                        ref.read(meetingsProvider.notifier).refresh(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        MinuteSpacing.md,
                        MinuteSpacing.xs,
                        MinuteSpacing.md,
                        108,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: MinuteSpacing.sm),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Dismissible(
                          key: ValueKey('meeting_${item.meeting.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(
                              horizontal: MinuteSpacing.lg,
                            ),
                            decoration: BoxDecoration(
                              color: c.danger,
                              borderRadius: BorderRadius.circular(
                                MinuteRadii.card,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Delete',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: c.accentForeground,
                                  ),
                                ),
                                const SizedBox(width: MinuteSpacing.sm),
                                Icon(
                                  Icons.delete_outline,
                                  color: c.accentForeground,
                                ),
                              ],
                            ),
                          ),
                          onDismissed: (_) => _handleSoftDelete(item),
                          child: _LibraryMeetingRow(
                            key: ValueKey('row_${item.meeting.id}'),
                            item: item,
                            onTap: () =>
                                context.push('/meeting/${item.meeting.id}'),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryMeetingRow extends ConsumerWidget {
  const _LibraryMeetingRow({
    super.key,
    required this.item,
    required this.onTap,
  });

  final MeetingListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peaksAsync = ref.watch(meetingPeaksProvider(item.meeting.peaksPath));
    final isFailed = item.meeting.status.toLowerCase() == 'failed';
    return MeetingCard(
      item: item,
      peaks: peaksAsync.value,
      onTap: onTap,
      onRetry: isFailed
          ? () async {
              final ok = await ensureUploadConsent(context, ref);
              if (!ok) return;
              await dispatchMeetingTranscription(ref, item.meeting.id);
            }
          : null,
    );
  }
}
