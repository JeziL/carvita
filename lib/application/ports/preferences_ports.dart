abstract interface class DefaultVehiclePreferences {
  Future<int?> getDefaultVehicleId();

  Future<void> setDefaultVehicleId(int? vehicleId);
}

abstract interface class ReminderPreferences {
  Future<bool> getNotificationsEnabled();

  Future<void> setNotificationsEnabled(bool enabled);

  Future<int> getReminderLeadTimeDays();
}
