import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../models/recording_item.dart';
import '../providers/app_providers.dart';
import '../theme/minute_tokens.dart';

/// Top-level navigation shell with Library, Search, Settings tabs and a
/// prominent centered Record action button.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: const _FloatingRecordFab(),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onSelectBranch: _onSelectBranch,
      ),
    );
  }

  void _onSelectBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _FloatingRecordFab extends ConsumerWidget {
  const _FloatingRecordFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.minuteColors;
    final rec = ref.watch(
      recordingControllerProvider.select(
        (s) => (
          status: s.status,
          isForceMode: s.isForceMode,
          elapsedSeconds: s.elapsed.inSeconds,
        ),
      ),
    );
    final isActive = rec.status != RecorderStatus.idle;
    final elapsedText =
        TimelineMarker.formatTimestamp(rec.elapsedSeconds * 1000);

    final recordButtonLabel = switch (rec.status) {
      RecorderStatus.recording =>
        rec.isForceMode ? 'FORCE • $elapsedText' : 'Recording • $elapsedText',
      RecorderStatus.paused => 'Paused • $elapsedText',
      RecorderStatus.finalizing => 'Saving...',
      RecorderStatus.idle => 'Record',
    };

    final recordSemanticLabel = isActive
        ? 'Return to active recording, elapsed $elapsedText'
        : 'Record new meeting';

    return Semantics(
      button: true,
      label: recordSemanticLabel,
      child: Material(
        color: rec.status == RecorderStatus.recording ? c.danger : c.accent,
        elevation: 2,
        borderRadius: BorderRadius.circular(MinuteRadii.pill),
        child: InkWell(
          onTap: () => context.push('/record'),
          borderRadius: BorderRadius.circular(MinuteRadii.pill),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52, minWidth: 136),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MinuteSpacing.lg,
                vertical: 12,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive ? Icons.graphic_eq : Icons.mic,
                    color: c.accentForeground,
                    size: 22,
                  ),
                  const SizedBox(width: MinuteSpacing.sm),
                  Flexible(
                    child: Text(
                      recordButtonLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: c.accentForeground,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.onSelectBranch,
  });

  final int currentIndex;
  final ValueChanged<int> onSelectBranch;

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _BottomNavDestination(
                label: 'Library',
                icon: Icons.library_books_outlined,
                selectedIcon: Icons.library_books,
                selected: currentIndex == 0,
                onTap: () => onSelectBranch(0),
              ),
            ),
            Expanded(
              child: _BottomNavDestination(
                label: 'Search',
                icon: Icons.search_outlined,
                selectedIcon: Icons.search,
                selected: currentIndex == 1,
                onTap: () => onSelectBranch(1),
              ),
            ),
            Expanded(
              child: _BottomNavDestination(
                label: 'Settings',
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                selected: currentIndex == 2,
                onTap: () => onSelectBranch(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavDestination extends StatelessWidget {
  const _BottomNavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final fg = selected ? c.accentText : c.textSecondary;

    return Semantics(
      selected: selected,
      button: true,
      label: '$label tab',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MinuteSpacing.xs,
              vertical: 6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: MinuteMotion.duration(context, MinuteMotion.fast),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? c.accentSubtle : Colors.transparent,
                    borderRadius: BorderRadius.circular(MinuteRadii.pill),
                  ),
                  child: Icon(
                    selected ? selectedIcon : icon,
                    size: 22,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: fg,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
