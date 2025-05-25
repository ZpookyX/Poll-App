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

// We don't want to reinitialize the router everytime we rebuild poll app
GoRouter initRouterOnce(AuthProvider auth) {
  _router ??= createRouter(auth);
  return _router!;
}

// The router depends on auth state to conditionally redirect to login or home
GoRouter createRouter(AuthProvider auth) => GoRouter(
  initialLocation: '/',
  refreshListenable: auth,  // It listens to auth for UI changes
  redirect: (context, state) {
    if (!auth.ready) return null;

    final loggedIn = auth.isLoggedIn;
    final goingToLogin = state.uri.path == '/login';

    // Forces to go back to login screen if not logged in
    if (!loggedIn && !goingToLogin) return '/login';

    // If not logged in then we can't access login screen
    if (loggedIn && goingToLogin) return '/';

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    // Shell route exists to have them share a NavBar
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

    // Other Routes without Navbar
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

    // Poll-creation screen: is outside ShellRoute to not have NavBar
    GoRoute(
      name: 'create',
      path: '/create',
      builder: (_, __) => const CreatePollScreen(),
    ),

    // Poll screen
    GoRoute(
      name: 'poll',
      path: '/poll/:id',
      builder: (context, state) {
        final pollId = state.pathParameters['id']!;
        // If we navigated to the poll screen from the poll creation screen
        // then we go back to the home screen, else we pop the navigation stack
        // and can therefore go back to other places like the profile
        final fromCreate = state.uri.queryParameters['fromCreate'] == 'true';
        return PollScreen(pollId: pollId, fromCreate: fromCreate);
      },
    ),
  ],
);

// BottomNavbar navigation
int _calculateIndex(String path) {
  if (path == '/') return 0;
  if (path == '/create') return 1;
  if (path == '/settings') return 2;
  if (path.startsWith('/profile')) return 3;
  return 0;
}
