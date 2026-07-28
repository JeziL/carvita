import 'dart:async';
import 'dart:developer' as developer;

import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:carvita/application/ports/clock.dart';
import 'package:carvita/application/ports/reminder_schedule_port.dart';

class ReminderScheduleService implements ReminderSchedulePort {
  ReminderScheduleService(this._deviceTimeZone, this._clock);

  final DeviceTimeZonePort _deviceTimeZone;
  final Clock _clock;

  tz.Location? _location;
  _CalendarDate? _lastObservedDate;
  Future<ReminderScheduleRefresh>? _refreshInFlight;
  bool _timeZoneDatabaseInitialized = false;

  @override
  Future<ReminderScheduleRefresh> refreshTimeZone() {
    return _refreshInFlight ??= _refresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<ReminderScheduleRefresh> _refresh() async {
    if (!_timeZoneDatabaseInitialized) {
      tz_data.initializeTimeZones();
      _timeZoneDatabaseInitialized = true;
    }

    var usedFallback = false;
    tz.Location resolvedLocation;
    try {
      final timeZoneId = await _deviceTimeZone.getLocalTimeZoneId();
      resolvedLocation = tz.getLocation(timeZoneId);
    } catch (error, stackTrace) {
      usedFallback = true;
      resolvedLocation = _location ?? tz.UTC;
      assert(() {
        developer.log(
          'Unable to resolve the device time zone; retaining a safe fallback',
          name: 'carvita.reminders',
          error: error,
          stackTrace: stackTrace,
        );
        return true;
      }());
    }

    final previousLocationName = _location?.name;
    final timeZoneChanged =
        previousLocationName != null &&
        previousLocationName != resolvedLocation.name;
    _location = resolvedLocation;
    tz.setLocalLocation(resolvedLocation);

    final now = tz.TZDateTime.from(_clock.now(), resolvedLocation);
    final observedDate = _CalendarDate(now.year, now.month, now.day);
    final calendarDateChanged =
        _lastObservedDate != null && _lastObservedDate != observedDate;
    _lastObservedDate = observedDate;

    return ReminderScheduleRefresh(
      timeZoneChanged: timeZoneChanged,
      calendarDateChanged: calendarDateChanged,
      timeZoneId: resolvedLocation.name,
      usedFallback: usedFallback,
    );
  }

  @override
  DateTime? calculateNotificationTime({
    required DateTime predictedDueDate,
    required int leadTimeDays,
    required DateTime now,
  }) {
    if (leadTimeDays < 0) {
      throw ArgumentError.value(
        leadTimeDays,
        'leadTimeDays',
        'Lead time cannot be negative',
      );
    }

    final location = _location;
    if (location == null) {
      throw StateError('The reminder time zone has not been initialized');
    }

    final dueCalendarDate = DateTime.utc(
      predictedDueDate.year,
      predictedDueDate.month,
      predictedDueDate.day,
    );
    final requestedCalendarDate = dueCalendarDate.subtract(
      Duration(days: leadTimeDays),
    );
    final requestedNoon = tz.TZDateTime(
      location,
      requestedCalendarDate.year,
      requestedCalendarDate.month,
      requestedCalendarDate.day,
      12,
    );
    final localNow = tz.TZDateTime.from(now, location);
    if (requestedNoon.isAfter(localNow)) {
      return requestedNoon;
    }

    final todayNoon = tz.TZDateTime(
      location,
      localNow.year,
      localNow.month,
      localNow.day,
      12,
    );
    final nextAvailableNoon = todayNoon.isAfter(localNow)
        ? todayNoon
        : tz.TZDateTime(
            location,
            localNow.year,
            localNow.month,
            localNow.day + 1,
            12,
          );
    final dueNoon = tz.TZDateTime(
      location,
      dueCalendarDate.year,
      dueCalendarDate.month,
      dueCalendarDate.day,
      12,
    );

    return nextAvailableNoon.isAfter(dueNoon) ? null : nextAvailableNoon;
  }
}

final class _CalendarDate {
  const _CalendarDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  @override
  bool operator ==(Object other) {
    return other is _CalendarDate &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);
}
