import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/app_shell.dart';
import '../screens/library_screen.dart';
import '../screens/meeting_detail_screen.dart';
import '../screens/record_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';

/// Switches to the Library bottom-nav tab first (via `go('/library')`), then
/// pushes `/meeting/$meetingId` on top so back navigation returns to Library.
void navigateToMeetingOverLibrary(
  GoRouter router,
  String meetingId, {
  int? seekSec,
}) {
  final target = seekSec != null
      ? '/meeting/$meetingId?seekSec=$seekSec'
      : '/meeting/$meetingId';
  _navigateToRootThenPush(router, target);
}

/// Switches to the Library bottom-nav tab first, then pushes `/record` on top.
void navigateToRecordOverLibrary(GoRouter router) {
  final current = router.routerDelegate.currentConfiguration;
  final topPath = current.matches.isEmpty ? '' : current.last.matchedLocation;
  if (topPath == '/record' || topPath == '/library/record') {
    return;
  }
  _navigateToRootThenPush(router, '/record');
}

bool _isCleanLibraryBase(GoRouter router) {
  final config = router.routerDelegate.currentConfiguration;
  return config.matches.length == 1 &&
      config.uri.path == '/library' &&
      config.last.matchedLocation == '/library';
}

void _navigateToRootThenPush(GoRouter router, String target) {
  if (_isCleanLibraryBase(router)) {
    unawaited(router.push(target));
    return;
  }

  late VoidCallback listener;
  listener = () {
    if (_isCleanLibraryBase(router)) {
      router.routerDelegate.removeListener(listener);
      unawaited(router.push(target));
    }
  };
  router.routerDelegate.addListener(listener);
  router.go('/library');
}

Widget _buildMeetingDetailFromState(GoRouterState state) {
  final id = state.pathParameters['id']!;
  final seekRaw = state.uri.queryParameters['seekSec'];
  final initialSeekSeconds = seekRaw != null ? int.tryParse(seekRaw) : null;
  return MeetingDetailScreen(
    meetingId: id,
    initialSeekSeconds: initialSeekSeconds,
  );
}

/// Builds a fresh [GoRouter] instance for Minit.
GoRouter createAppRouter({String initialLocation = '/library'}) {
  final rootNavKey = GlobalKey<NavigatorState>(
    debugLabel: 'minitRootNavigator',
  );

  return GoRouter(
    navigatorKey: rootNavKey,
    initialLocation: initialLocation,
    redirect: (context, state) {
      // Ensure cold deep links or notification launches into /record or
      // /meeting/:id land with /library underneath in the navigation stack.
      final isColdStart = rootNavKey.currentState == null;
      if (!isColdStart) return null;

      final path = state.uri.path;
      if (path == '/record') {
        return '/library/record';
      }
      if (path.startsWith('/meeting/')) {
        final q = state.uri.hasQuery ? '?${state.uri.query}' : '';
        return '/library$path$q';
      }
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                name: 'library',
                builder: (context, state) => const LibraryScreen(),
                routes: [
                  GoRoute(
                    path: 'record',
                    name: 'libraryRecord',
                    parentNavigatorKey: rootNavKey,
                    builder: (context, state) => const RecordScreen(),
                  ),
                  GoRoute(
                    path: 'meeting/:id',
                    name: 'libraryMeetingDetail',
                    parentNavigatorKey: rootNavKey,
                    builder: (context, state) =>
                        _buildMeetingDetailFromState(state),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                name: 'search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/record',
        name: 'record',
        parentNavigatorKey: rootNavKey,
        builder: (context, state) => const RecordScreen(),
      ),
      GoRoute(
        path: '/meeting/:id',
        name: 'meetingDetail',
        parentNavigatorKey: rootNavKey,
        builder: (context, state) => _buildMeetingDetailFromState(state),
      ),
    ],
  );
}

/// Shared router provider consumed by [MaterialApp.router].
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter();
  ref.onDispose(router.dispose);
  return router;
});
