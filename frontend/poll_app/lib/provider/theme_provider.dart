import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _mode = AppThemeMode.system;

  AppThemeMode get mode => _mode;

  ThemeMode get themeMode {
    switch (_mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
      default:
        return ThemeMode.dark;
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

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('themeMode') ?? 0;
    _mode = AppThemeMode.values[index];
    notifyListeners();
  }

  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', _mode.index);
  }
}
