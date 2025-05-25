import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'provider/auth_provider.dart';
import 'provider/theme_provider.dart';
import 'provider/profile_provider.dart';
import 'provider/poll_provider.dart';
import 'routes/app_router.dart';

void main() => runApp(
  // ---------- Global providers ----------
  // MultiProvider makes it so that we don't have to nest them in each other
  MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ChangeNotifierProvider(create: (_) => PollProvider()),
    ],
    child: const PollApp(),
  ),
);

// ---------- Root app widget ----------
class PollApp extends StatelessWidget {
  const PollApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();

    // Initialize routing once with access to auth state
    final router = initRouterOnce(auth);

    return MaterialApp.router(
      title: 'Polls',
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: theme.themeMode,     // Reactively switch between light/dark
      routerConfig: router,           // GoRouter config with auth guarding
    );
  }
}
