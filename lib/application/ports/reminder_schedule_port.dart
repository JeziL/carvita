abstract interface class DeviceTimeZonePort {
  Future<String> getLocalTimeZoneId();
}

final class ReminderScheduleRefresh {
  const ReminderScheduleRefresh({
    required this.timeZoneChanged,
    required this.calendarDateChanged,
    required this.timeZoneId,
    required this.usedFallback,
  });

  final bool timeZoneChanged;
  final bool calendarDateChanged;
  final String timeZoneId;
  final bool usedFallback;

  bool get contextChanged => timeZoneChanged || calendarDateChanged;
}

abstract interface class ReminderSchedulePort {
  Future<ReminderScheduleRefresh> refreshTimeZone();

  DateTime? calculateNotificationTime({
    required DateTime predictedDueDate,
    required int leadTimeDays,
    required DateTime now,
  });
}
