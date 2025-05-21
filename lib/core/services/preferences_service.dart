import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DueReminderThresholdValue {
  week,
  month,
  halfYear
}

extension DueReminderThresholdDetails on DueReminderThresholdValue {
  int get days {
    switch (this) {
      case DueReminderThresholdValue.week: return 7;
      case DueReminderThresholdValue.month: return 30;
      case DueReminderThresholdValue.halfYear: return 182;
    }
  }

  String displayString(BuildContext context) {
    switch (this) {
      case DueReminderThresholdValue.week: return AppLocalizations.of(context)!.thresholdWeek;
      case DueReminderThresholdValue.month: return AppLocalizations.of(context)!.thresholdMonth;
      case DueReminderThresholdValue.halfYear: return AppLocalizations.of(context)!.thresholdHalfYear;
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

  Future<void> setDueReminderThreshold(DueReminderThresholdValue threshold) async {
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
}
