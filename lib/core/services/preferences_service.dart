import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:carvita/i18n/generated/app_localizations.dart';

enum AppThemePreference { system, light, dark, custom }

extension AppThemePreferenceDetails on AppThemePreference {
  String get keyString => name;
  String displayString(BuildContext context) {
    switch (this) {
      case AppThemePreference.system:
        return AppLocalizations.of(context)!.themeSystem;
      case AppThemePreference.light:
        return AppLocalizations.of(context)!.themeLight;
      case AppThemePreference.dark:
        return AppLocalizations.of(context)!.themeDark;
      case AppThemePreference.custom:
        return AppLocalizations.of(context)!.themeCustom;
    }
  }
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

  String displayString(BuildContext context) {
    switch (this) {
      case DueReminderThresholdValue.week:
        return AppLocalizations.of(context)!.thresholdWeek;
      case DueReminderThresholdValue.month:
        return AppLocalizations.of(context)!.thresholdMonth;
      case DueReminderThresholdValue.halfYear:
        return AppLocalizations.of(context)!.thresholdHalfYear;
    }
  }

  String get keyString => name;
}

class PreferencesService {
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

  Future<void> setDefaultVehicleId(int? vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    if (vehicleId == null) {
      await prefs.remove(_defaultVehicleIdKey);
    } else {
      await prefs.setInt(_defaultVehicleIdKey, vehicleId);
    }
  }

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

  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? false;
  }

  static const List<int> reminderLeadTimeOptionsInDays = [1, 3, 7, 14, 30];

  Future<void> setReminderLeadTimeDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderLeadTimeDaysKey, days);
  }

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
