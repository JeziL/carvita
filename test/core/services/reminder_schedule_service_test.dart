import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:timezone/timezone.dart' as tz;

import 'package:carvita/application/ports/clock.dart';
import 'package:carvita/application/ports/reminder_schedule_port.dart';
import 'package:carvita/core/services/reminder_schedule_service.dart';

void main() {
  test('schedules the requested calendar day at local noon', () async {
    final clock = _MutableClock(DateTime.utc(2026, 7, 27, 1));
    final service = ReminderScheduleService(
      _FakeDeviceTimeZone(['Asia/Shanghai']),
      clock,
    );

    await service.refreshTimeZone();
    final scheduled = service.calculateNotificationTime(
      predictedDueDate: DateTime(2026, 8, 3),
      leadTimeDays: 7,
      now: clock.now(),
    );

    expect(scheduled, isA<tz.TZDateTime>());
    expect(scheduled!.year, 2026);
    expect(scheduled.month, 7);
    expect(scheduled.day, 27);
    expect(scheduled.hour, 12);
    expect(scheduled.timeZoneOffset, const Duration(hours: 8));
    expect(scheduled.toUtc(), DateTime.utc(2026, 7, 27, 4));
  });

  test('uses the DST offset in effect on the reminder date', () async {
    final clock = _MutableClock(DateTime.utc(2026, 3, 7, 15));
    final service = ReminderScheduleService(
      _FakeDeviceTimeZone(['America/New_York']),
      clock,
    );

    await service.refreshTimeZone();
    final spring = service.calculateNotificationTime(
      predictedDueDate: DateTime(2026, 3, 10),
      leadTimeDays: 2,
      now: clock.now(),
    );

    expect(spring!.year, 2026);
    expect(spring.month, 3);
    expect(spring.day, 8);
    expect(spring.hour, 12);
    expect(spring.timeZoneOffset, const Duration(hours: -4));
    expect(spring.toUtc(), DateTime.utc(2026, 3, 8, 16));

    clock.value = DateTime.utc(2026, 10, 31, 14);
    final autumn = service.calculateNotificationTime(
      predictedDueDate: DateTime(2026, 11, 3),
      leadTimeDays: 2,
      now: clock.now(),
    );

    expect(autumn!.year, 2026);
    expect(autumn.month, 11);
    expect(autumn.day, 1);
    expect(autumn.hour, 12);
    expect(autumn.timeZoneOffset, const Duration(hours: -5));
    expect(autumn.toUtc(), DateTime.utc(2026, 11, 1, 17));
  });

  test('a passed lead time moves to the next available noon', () async {
    final clock = _MutableClock(DateTime.utc(2026, 7, 27, 5));
    final service = ReminderScheduleService(
      _FakeDeviceTimeZone(['Asia/Shanghai']),
      clock,
    );

    await service.refreshTimeZone();
    final scheduled = service.calculateNotificationTime(
      predictedDueDate: DateTime(2026, 7, 30),
      leadTimeDays: 3,
      now: clock.now(),
    );

    expect(scheduled!.year, 2026);
    expect(scheduled.month, 7);
    expect(scheduled.day, 28);
    expect(scheduled.hour, 12);
  });

  test('does not catch up after the final eligible noon', () async {
    final clock = _MutableClock(DateTime.utc(2026, 7, 30, 5));
    final service = ReminderScheduleService(
      _FakeDeviceTimeZone(['Asia/Shanghai']),
      clock,
    );

    await service.refreshTimeZone();

    expect(
      service.calculateNotificationTime(
        predictedDueDate: DateTime(2026, 7, 30),
        leadTimeDays: 3,
        now: clock.now(),
      ),
      isNull,
    );
  });

  test('detects time zone and local calendar-date changes', () async {
    final clock = _MutableClock(DateTime.utc(2026, 7, 27, 12));
    final deviceTimeZone = _FakeDeviceTimeZone([
      'Asia/Shanghai',
      'America/Los_Angeles',
      'America/Los_Angeles',
    ]);
    final service = ReminderScheduleService(deviceTimeZone, clock);

    final initial = await service.refreshTimeZone();
    expect(initial.contextChanged, isFalse);
    expect(initial.timeZoneId, 'Asia/Shanghai');

    final travelled = await service.refreshTimeZone();
    expect(travelled.timeZoneChanged, isTrue);
    expect(travelled.calendarDateChanged, isFalse);
    expect(travelled.timeZoneId, 'America/Los_Angeles');

    clock.value = DateTime.utc(2026, 7, 28, 12);
    final nextDay = await service.refreshTimeZone();
    expect(nextDay.timeZoneChanged, isFalse);
    expect(nextDay.calendarDateChanged, isTrue);
  });

  test('invalid device zones safely fall back to UTC', () async {
    final service = ReminderScheduleService(
      _FakeDeviceTimeZone(['Not/A_Real_Zone']),
      _MutableClock(DateTime.utc(2026, 7, 27)),
    );

    final refresh = await service.refreshTimeZone();

    expect(refresh.usedFallback, isTrue);
    expect(refresh.timeZoneId, 'UTC');
    expect(tz.local.name, 'UTC');
  });

  test('concurrent refreshes share one device lookup', () async {
    final lookup = Completer<String>();
    final deviceTimeZone = _BlockingDeviceTimeZone(lookup);
    final service = ReminderScheduleService(
      deviceTimeZone,
      _MutableClock(DateTime.utc(2026, 7, 27)),
    );

    final first = service.refreshTimeZone();
    final second = service.refreshTimeZone();
    lookup.complete('Asia/Shanghai');

    await Future.wait([first, second]);
    expect(deviceTimeZone.lookupCount, 1);
  });
}

class _MutableClock implements Clock {
  _MutableClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

class _FakeDeviceTimeZone implements DeviceTimeZonePort {
  _FakeDeviceTimeZone(List<String> values) : _values = values;

  final List<String> _values;
  int _index = 0;

  @override
  Future<String> getLocalTimeZoneId() async {
    final value = _values[_index.clamp(0, _values.length - 1)];
    _index++;
    return value;
  }
}

class _BlockingDeviceTimeZone implements DeviceTimeZonePort {
  _BlockingDeviceTimeZone(this.lookup);

  final Completer<String> lookup;
  int lookupCount = 0;

  @override
  Future<String> getLocalTimeZoneId() {
    lookupCount++;
    return lookup.future;
  }
}
