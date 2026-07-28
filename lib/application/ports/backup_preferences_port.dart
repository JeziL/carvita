enum BackupPreferenceValueType { boolean, integer, string }

const Map<String, BackupPreferenceValueType> backupPreferenceSchema = {
  'default_vehicle_id': BackupPreferenceValueType.integer,
  'due_reminder_threshold': BackupPreferenceValueType.string,
  'due_reminder_item_count': BackupPreferenceValueType.integer,
  'notifications_enabled': BackupPreferenceValueType.boolean,
  'reminder_lead_time_days': BackupPreferenceValueType.integer,
  'locale_language_code': BackupPreferenceValueType.string,
  'locale_script_code': BackupPreferenceValueType.string,
  'locale_country_code': BackupPreferenceValueType.string,
  'mileage_unit': BackupPreferenceValueType.string,
  'theme_preference': BackupPreferenceValueType.string,
  'custom_theme_seed_color': BackupPreferenceValueType.integer,
};

abstract interface class BackupPreferencesPort {
  Future<Map<String, Object>> readBackupPreferences();

  /// Replaces only the allowlisted preferences. Implementations must restore
  /// the previous allowlisted values if a write fails.
  Future<void> replaceBackupPreferences(Map<String, Object> values);
}

Map<String, Object> validateBackupPreferenceValues(
  Map<String, Object?> values,
) {
  final validated = <String, Object>{};
  for (final entry in values.entries) {
    final expectedType = backupPreferenceSchema[entry.key];
    if (expectedType == null) {
      throw FormatException('Unknown backup preference key: ${entry.key}');
    }
    final value = entry.value;
    final valid = switch (expectedType) {
      BackupPreferenceValueType.boolean => value is bool,
      BackupPreferenceValueType.integer => value is int,
      BackupPreferenceValueType.string => value is String,
    };
    if (!valid || value == null) {
      throw FormatException('Invalid backup preference type for ${entry.key}');
    }
    validated[entry.key] = value;
  }
  return Map.unmodifiable(validated);
}
