// main.dart – Flutter 3.22 / google_sign_in 6.3.0
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'routes/app_router.dart';
import 'services/auth_provider.dart';

void main() => runApp(
  ChangeNotifierProvider(create: (_) => AuthProvider(), child: const PollApp()),
);

class PollApp extends StatelessWidget {
  const PollApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return MaterialApp.router(
      title: 'Polls',
      theme: ThemeData(useMaterial3: true),
      routerConfig: createRouter(auth),
    );
  }
}