
// main.dart – Flutter 3.22 / google_sign_in 6.3.0
import 'package:flutter/material.dart';
import 'package:poll_app/provider/poll_provider.dart';
import 'package:provider/provider.dart';
import '../../lib/routes/app_router.dart';
import '../../lib/provider/auth_provider.dart';
import '../../lib/provider/theme_provider.dart';
import '../../lib/provider/profile_provider.dart';
void main() => runApp(
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
class PollApp extends StatelessWidget {
  const PollApp({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final router = initRouterOnce(auth);
    return MaterialApp.router(
      title: 'Polls',
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: theme.themeMode,
      routerConfig: router,
    );
  }
}
