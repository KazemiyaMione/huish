import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyThemeMode = 'theme_mode';
  static const _keyThemeColor = 'theme_color';

  ThemeMode _themeMode = ThemeMode.light;
  Color _seedColor = const Color(0xFF1565C0);

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;
  bool get isDark => _themeMode == ThemeMode.dark;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyThemeMode);
    if (v != null) {
      _themeMode = v == 'dark' ? ThemeMode.dark : ThemeMode.light;
    }
    final c = prefs.getInt(_keyThemeColor);
    if (c != null) {
      _seedColor = Color(c);
    }
    if (v != null || c != null) notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, isDark ? 'dark' : 'light');
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeColor, color.toARGB32());
  }
}
