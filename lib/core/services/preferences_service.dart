import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:carvita/application/ports/backup_preferences_port.dart';
import 'package:carvita/application/ports/preferences_ports.dart';

enum AppThemePreference { system, light, dark, custom }

extension AppThemePreferenceDetails on AppThemePreference {
  String get keyString => name;
}

enum DueReminderThresholdValue { week, month, halfYear }

extension DueReminderThresholdDetails on DueReminderThresholdValue {
  int get days {
    switch (this) {
      case DueReminderThresholdValue.week:
        return 7;
      case DueReminderThresholdValue.month:
        return 30;
      case DueReminderThresholdValue.halfYear:
        return 182;
    }
  }

  String get keyString => name;
}

class PreferencesService
    implements
        DefaultVehiclePreferences,
        ReminderPreferences,
        BackupPreferencesPort {
  static const String _defaultVehicleIdKey = 'default_vehicle_id';
  static const String _dueReminderThresholdKey = 'due_reminder_threshold';
  static const String _dueReminderItemCountKey = 'due_reminder_item_count';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _reminderLeadTimeDaysKey = 'reminder_lead_time_days';
  static const String _appLanguageCodeKey = 'locale_language_code';
  static const String _appScriptCodeKey = 'locale_script_code';
  static const String _appCountryCodeKey = 'locale_country_code';
  static const String _mileageUnitKey = 'mileage_unit';
  static const String _themePreferenceKey = 'theme_preference';
  static const String _customThemeSeedColorKey = 'custom_theme_seed_color';

  @override
  Future<Map<String, Object>> readBackupPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final values = <String, Object?>{
      for (final key in backupPreferenceSchema.keys) key: preferences.get(key),
    }..removeWhere((_, value) => value == null);
    return validateBackupPreferenceValues(values);
  }

  @override
  Future<void> replaceBackupPreferences(Map<String, Object> values) async {
    final validated = validateBackupPreferenceValues(values);
    final previousValues = await readBackupPreferences();
    final preferences = await SharedPreferences.getInstance();

    try {
      await _writeBackupPreferences(preferences, validated);
    } catch (error, stackTrace) {
      try {
        await _writeBackupPreferences(preferences, previousValues);
      } catch (_) {
        // Preserve the original write failure for the restore coordinator.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _writeBackupPreferences(
    SharedPreferences preferences,
    Map<String, Object> values,
  ) async {
    for (final key in backupPreferenceSchema.keys) {
      if (!await preferences.remove(key)) {
        throw StateError('Could not clear backup preference $key');
      }
    }
    for (final entry in values.entries) {
      final saved = switch (entry.value) {
        final bool value => await preferences.setBool(entry.key, value),
        final int value => await preferences.setInt(entry.key, value),
        final String value => await preferences.setString(entry.key, value),
        _ => false,
      };
      if (!saved) {
        throw StateError('Could not restore backup preference ${entry.key}');
      }
    }
  }

  @override
  Future<void> setDefaultVehicleId(int? vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    if (vehicleId == null) {
      await prefs.remove(_defaultVehicleIdKey);
    } else {
      await prefs.setInt(_defaultVehicleIdKey, vehicleId);
    }
  }

  @override
  Future<int?> getDefaultVehicleId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_defaultVehicleIdKey);
  }

  Future<void> setDueReminderThreshold(
    DueReminderThresholdValue threshold,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dueReminderThresholdKey, threshold.keyString);
  }

  Future<DueReminderThresholdValue> getDueReminderThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    final thresholdString = prefs.getString(_dueReminderThresholdKey);
    if (thresholdString == null) {
      return DueReminderThresholdValue.halfYear;
    }
    return DueReminderThresholdValue.values.firstWhere(
      (e) => e.keyString == thresholdString,
      orElse: () => DueReminderThresholdValue.halfYear,
    );
  }

  Future<void> setDueReminderItemCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dueReminderItemCountKey, count);
  }

  Future<int> getDueReminderItemCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dueReminderItemCountKey) ?? 3;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
  }

  @override
  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? false;
  }

  static const List<int> reminderLeadTimeOptionsInDays = [1, 3, 7, 14, 30];

  Future<void> setReminderLeadTimeDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderLeadTimeDaysKey, days);
  }

  @override
  Future<int> getReminderLeadTimeDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_reminderLeadTimeDaysKey) ?? 7;
  }

  Future<void> setAppLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      // follow system
      await prefs.remove(_appLanguageCodeKey);
      await prefs.remove(_appScriptCodeKey);
      await prefs.remove(_appCountryCodeKey);
    } else {
      await prefs.setString(_appLanguageCodeKey, locale.languageCode);
      if (locale.scriptCode != null && locale.scriptCode!.isNotEmpty) {
        await prefs.setString(_appScriptCodeKey, locale.scriptCode!);
      } else {
        await prefs.remove(_appScriptCodeKey);
      }
      if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
        await prefs.setString(_appCountryCodeKey, locale.countryCode!);
      } else {
        await prefs.remove(_appCountryCodeKey);
      }
    }
  }

  Future<Locale?> getAppLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final String? languageCode = prefs.getString(_appLanguageCodeKey);
    if (languageCode == null) {
      return null; // should follow system
    }
    final String? countryCode = prefs.getString(_appCountryCodeKey);
    final String? scriptCode = prefs.getString(_appScriptCodeKey);
    return Locale.fromSubtags(
      languageCode: languageCode,
      countryCode: countryCode,
      scriptCode: scriptCode,
    );
  }

  Future<void> setMileageUnit(String unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mileageUnitKey, unit);
  }

  Future<String> getMileageUnit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_mileageUnitKey) ?? 'km';
  }

  Future<void> setThemePreference(AppThemePreference preference) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePreferenceKey, preference.keyString);
  }

  Future<AppThemePreference> getThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final preferenceString = prefs.getString(_themePreferenceKey);
    if (preferenceString == null) {
      return AppThemePreference.system;
    }
    return AppThemePreference.values.firstWhere(
      (e) => e.keyString == preferenceString,
      orElse: () => AppThemePreference.system,
    );
  }

  Future<void> setCustomThemeSeedColor(Color? color) async {
    final prefs = await SharedPreferences.getInstance();
    if (color == null) {
      await prefs.remove(_customThemeSeedColorKey);
    } else {
      await prefs.setInt(_customThemeSeedColorKey, color.toARGB32());
    }
  }

  Future<Color?> getCustomThemeSeedColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_customThemeSeedColorKey);
    return colorValue != null ? Color(colorValue) : null;
  }
}
