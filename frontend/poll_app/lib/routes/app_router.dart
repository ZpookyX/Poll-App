import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/create_poll_screen.dart';
import '../screens/poll_screen.dart';
import '../provider/auth_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../screens/settings_screen.dart';
import '../screens/profile_screen.dart';

GoRouter? _router;

GoRouter initRouterOnce(AuthProvider auth) {
  _router ??= createRouter(auth);
  return _router!;
}

GoRouter createRouter(AuthProvider auth) => GoRouter(
  initialLocation: '/',
  refreshListenable: auth,
  redirect: (_, state) {
    final loggedIn = auth.isLoggedIn;
    final onLogin = state.matchedLocation == '/login';
    if (!loggedIn && !onLogin) return '/login';
    if (loggedIn && onLogin) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),

    ShellRoute(
      builder: (context, state, child) => Scaffold(
        body: child,
        bottomNavigationBar: BottomNavBar(
          currentIndex: _calculateIndex(state.uri.path),
        ),
      ),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    ),

    GoRoute(path: '/create', builder: (_, __) => const CreatePollScreen()),
    GoRoute(
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
  switch (path) {
    case '/':
      return 0;
    case '/create':
      return 1;
    case '/settings':
      return 2;
    case '/profile':
      return 3;
    default:
      return 0;
  }
}