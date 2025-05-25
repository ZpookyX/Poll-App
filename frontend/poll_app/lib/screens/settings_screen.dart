import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/theme_provider.dart';

// The settings screen only has one setting which is changing the theme for now
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
            const Text("Appearance:", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            // We use a dropdown to make sure it can handle system and not just
            // dark/light modes. The dropdown also only deals with our enum
            // AppThemeMode which we define in theme_provider
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
                  value: AppThemeMode.light,
                  child: Text("Light mode"),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.system,
                  child: Text("System preference"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
