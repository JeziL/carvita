import 'package:flutter/material.dart';

import 'package:carvita/core/services/preferences_service.dart';

class ThemeProvider extends ChangeNotifier {
  final PreferencesService _preferencesService;

  AppThemePreference _themePreference = AppThemePreference.system;
  Color? _customSeedColor;

  ThemeProvider(this._preferencesService) {
    _loadPreferences();
  }

  AppThemePreference get themePreference => _themePreference;
  Color? get customSeedColor => _customSeedColor;

  ThemeMode get themeMode {
    switch (_themePreference) {
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
      case AppThemePreference
          .custom: // Custom seed can have light/dark variant based on system
      case AppThemePreference.system:
        return ThemeMode.system;
    }
  }

  Future<void> _loadPreferences() async {
    _themePreference = await _preferencesService.getThemePreference();
    _customSeedColor = await _preferencesService.getCustomThemeSeedColor();
    notifyListeners();
  }

  Future<void> setThemePreference(AppThemePreference preference) async {
    if (_themePreference == preference) return;
    _themePreference = preference;
    await _preferencesService.setThemePreference(preference);
    notifyListeners();
  }

  Future<void> setCustomSeedColor(Color color) async {
    if (_customSeedColor == color) return;
    _customSeedColor = color;
    await _preferencesService.setCustomThemeSeedColor(color);
    // If they pick a custom color, switch to custom theme mode
    if (_themePreference != AppThemePreference.custom) {
      await setThemePreference(AppThemePreference.custom);
    } else {
      notifyListeners(); // Just notify if already in custom mode
    }
  }
}
