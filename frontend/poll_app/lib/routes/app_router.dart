import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/create_poll_screen.dart';
import '../screens/poll_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/profile_screen.dart';
import '../provider/auth_provider.dart';
import '../widgets/bottom_nav_bar.dart';

final _shellNavKey = GlobalKey<NavigatorState>();

GoRouter? _router;

GoRouter initRouterOnce(AuthProvider auth) {
  _router ??= createRouter(auth);
  return _router!;
}

GoRouter createRouter(AuthProvider auth) => GoRouter(
  initialLocation: '/',
  refreshListenable: auth,
  redirect: (context, state) {
    final loggedIn = auth.isLoggedIn;
    final goingToLogin = state.uri.path == '/login';

    if (!loggedIn && !goingToLogin) return '/login';
    if (loggedIn && goingToLogin) return '/';

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavKey,
      builder: (context, state, child) => Scaffold(
        body: child,
        bottomNavigationBar: BottomNavBar(
          currentIndex: _calculateIndex(state.uri.path),
        ),
      ),
      routes: [
        GoRoute(
          name: 'home',
          path: '/',
          builder: (_, __) => const HomeScreen(),
        ),
        GoRoute(
          name: 'settings',
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
        ),
        GoRoute(
          name: 'profile_self',
          path: '/profile',
          builder: (_, __) => const ProfileScreen(),
        ),
      ],
    ),
    GoRoute(
      name: 'profile_detail',
      path: '/user/:id',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id']!);
        return ProfileScreen(
          key: ValueKey(state.uri.toString()),
          userId: id,
        );
      },
    ),
    GoRoute(
      name: 'create',
      path: '/create',
      builder: (_, __) => const CreatePollScreen(),
    ),
    GoRoute(
      name: 'poll',
      path: '/poll/:id',
      builder: (context, state) {
        final pollId = state.pathParameters['id']!;
        final fromCreate = state.uri.queryParameters['fromCreate'] == 'true';
        return PollScreen(pollId: pollId, fromCreate: fromCreate);
      },
    ),
  ],
);


int _calculateIndex(String path) {
  if (path == '/') return 0;
  if (path == '/create') return 1;
  if (path == '/settings') return 2;
  if (path.startsWith('/profile')) return 3;
  return 0;
}
