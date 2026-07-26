import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const _themeKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = _modeFromValue(prefs.getString(_themeKey));
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.system) {
      await prefs.remove(_themeKey);
    } else {
      await prefs.setString(_themeKey, mode.name);
    }
  }

  ThemeMode nextVisibleMode(Brightness platformBrightness) {
    final effectiveMode = _themeMode == ThemeMode.system
        ? platformBrightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light
        : _themeMode;

    return effectiveMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  static ThemeMode _modeFromValue(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
