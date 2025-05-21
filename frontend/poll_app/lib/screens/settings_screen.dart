import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Theme:", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            DropdownButton<AppThemeMode>(
              value: themeProvider.mode,
              onChanged: (mode) {
                if (mode != null) {
                  themeProvider.setTheme(mode);
                }
              },
              items: const [
                DropdownMenuItem(
                  value: AppThemeMode.dark,
                  child: Text("Dark mode"),
              ),
                DropdownMenuItem(
                  value: AppThemeMode.system,
                  child: Text("System preference"),
                ),

                DropdownMenuItem(
                  value: AppThemeMode.light,
                  child: Text("Light mode"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
