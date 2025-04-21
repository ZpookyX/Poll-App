import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // fire‑and‑forget; if it blows up you still see the UI
  loginDemo().catchError((e) => debugPrint('login failed: $e'));

  runApp(const PollApp());
}


class PollApp extends StatelessWidget {
  const PollApp({super.key});
  @override
  Widget build(BuildContext ctx) {
    return MaterialApp(
      title: 'Polls',
      theme: ThemeData(useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
