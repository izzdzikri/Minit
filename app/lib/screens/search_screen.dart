import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../data/database/app_database.dart';
import '../models/recording_item.dart';
import '../providers/app_providers.dart';
import '../theme/minute_tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/minute_back_button.dart';
import '../widgets/offline_banner.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/status_chip.dart';

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
}

final searchResultsProvider =
    FutureProvider.autoDispose<List<SearchHit>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return const [];
  return ref.watch(meetingRepositoryProvider).search(query);
});

/// Search across meeting titles and local transcript segments with highlighted
/// snippets and deep links straight to the matching timestamp.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final theme = Theme.of(context);
    final isOnline = ref.watch(connectivityOnlineProvider);
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const MinuteBackButton(),
        title: Semantics(header: true, child: const Text('Search')),
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
                    label: 'Search meeting titles and transcripts',
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) => ref
                          .read(searchQueryProvider.notifier)
                          .setQuery(value),
                      decoration: InputDecoration(
                        hintText: 'Search words in titles or transcripts...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _controller.clear();
                                  ref
                                      .read(searchQueryProvider.notifier)
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
              child: query.trim().isEmpty
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(
                        MinuteSpacing.md,
                        MinuteSpacing.md,
                        MinuteSpacing.md,
                        108,
                      ),
                      children: const [
                        EmptyState(
                          icon: Icons.search,
                          title: 'Search titles & transcripts',
                          message:
                              'Enter a topic, speaker word, or Malay/English phrase to jump straight to that moment.',
                        ),
                      ],
                    )
                  : resultsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(MinuteSpacing.md),
                        child: SkeletonLoader(itemCount: 3),
                      ),
                      error: (_, _) => Padding(
                        padding: const EdgeInsets.all(MinuteSpacing.md),
                        child: Center(
                          child: ErrorState(
                            message: 'Could not search local meetings.',
                            onRetry: () => ref.invalidate(searchResultsProvider),
                          ),
                        ),
                      ),
                      data: (hits) {
                        if (hits.isEmpty) {
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(
                              MinuteSpacing.md,
                              MinuteSpacing.md,
                              MinuteSpacing.md,
                              108,
                            ),
                            children: [
                              EmptyState(
                                icon: Icons.search_off,
                                title: 'No matches found',
                                message:
                                    'Nothing in your local titles or transcripts matched "${query.trim()}".',
                              ),
                            ],
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            MinuteSpacing.md,
                            MinuteSpacing.xs,
                            MinuteSpacing.md,
                            108,
                          ),
                          itemCount: hits.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: MinuteSpacing.sm),
                          itemBuilder: (context, index) {
                            final hit = hits[index];
                            final m = hit.meeting;
                            final dateText = DateFormat('d MMM, HH:mm')
                                .format(m.createdAt.toLocal());
                            final seekSec = hit.seekSec?.floor();
                            final ts = seekSec != null
                                ? TimelineMarker.formatTimestamp(seekSec * 1000)
                                : null;

                            return Semantics(
                              button: true,
                              label:
                                  '${m.title}${ts != null ? " at $ts" : ""}: ${hit.snippet}',
                              child: Card(
                                child: InkWell(
                                  borderRadius:
                                      BorderRadius.circular(MinuteRadii.card),
                                  onTap: () {
                                    if (seekSec != null) {
                                      context.push(
                                        '/meeting/${m.id}?seekSec=$seekSec',
                                      );
                                    } else {
                                      context.push('/meeting/${m.id}');
                                    }
                                  },
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.all(MinuteSpacing.md),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                m.title,
                                                style:
                                                    theme.textTheme.titleMedium,
                                              ),
                                            ),
                                            if (ts != null) ...[
                                              const SizedBox(
                                                  width: MinuteSpacing.sm),
                                              StatusChip(
                                                label: ts,
                                                tone: StatusChipTone.accent,
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: MinuteSpacing.xs),
                                        Text(
                                          hit.speakerName != null
                                              ? '${hit.speakerName}  •  $dateText'
                                              : dateText,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        const SizedBox(height: MinuteSpacing.sm),
                                        _HighlightedSnippet(
                                          text: hit.snippet,
                                          query: query.trim(),
                                          highlightBg: c.accentSubtle,
                                          highlightFg: c.accentText,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
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

class _HighlightedSnippet extends StatelessWidget {
  const _HighlightedSnippet({
    required this.text,
    required this.query,
    required this.highlightBg,
    required this.highlightFg,
  });

  final String text;
  final String query;
  final Color highlightBg;
  final Color highlightFg;

  @override
  Widget build(BuildContext context) {
    final baseStyle = MinuteTypography.editorialBody(context);
    if (query.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: TextStyle(
            backgroundColor: highlightBg,
            color: highlightFg,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      start = index + query.length;
    }

    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}
