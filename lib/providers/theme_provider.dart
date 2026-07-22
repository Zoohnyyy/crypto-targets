import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's [ThemeMode] and persists the user's choice.
///
/// Defaults to [ThemeMode.dark] on first launch to preserve the app's original
/// dark look, but the user can switch to light or follow the system setting.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider();

  static const _kThemeMode = 'theme_mode_v1';

  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  /// Load the persisted preference. Safe to call once at startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kThemeMode);
    _mode = ThemeMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ThemeMode.dark,
    );
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, mode.name);
  }

  /// Convenience toggle between light and dark (used by the app-bar button).
  Future<void> toggle() =>
      setMode(_mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}
