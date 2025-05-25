import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _mode = AppThemeMode.system; // Sets default setting to system

  AppThemeMode get mode => _mode;

  // Initializes flutters ThemeMode based on our enum values. ThemeMode controls
  // MaterialApp
  ThemeMode get themeMode {
    switch (_mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  ThemeProvider() {
    _loadTheme();
  }

  void setTheme(AppThemeMode newMode) {
    _mode = newMode;
    _saveTheme();
    notifyListeners();
  }

  // Loads theme mode from SharedPreferences on app start
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('themeMode') ?? AppThemeMode.system.index;
    _mode = AppThemeMode.values[index];
    notifyListeners();
  }

  // Saves current theme mode to SharedPreferences for persistence
  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', _mode.index);
  }
}
