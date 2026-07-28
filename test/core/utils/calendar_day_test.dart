import 'package:flutter_test/flutter_test.dart';

import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:carvita/core/utils/calendar_day.dart';

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('today, tomorrow, and yesterday use calendar dates', () {
    final now = DateTime(2026, 7, 28, 23, 59);

    expect(CalendarDay.daysBetween(now, DateTime(2026, 7, 28, 0, 1)), 0);
    expect(CalendarDay.daysBetween(now, DateTime(2026, 7, 29, 0, 1)), 1);
    expect(CalendarDay.daysBetween(now, DateTime(2026, 7, 27, 23, 59)), -1);
  });

  test('cross-month and leap-year boundaries count calendar days', () {
    expect(
      CalendarDay.daysBetween(
        DateTime(2024, 2, 28, 23),
        DateTime(2024, 3, 1, 1),
      ),
      2,
    );
    expect(
      CalendarDay.daysBetween(
        DateTime(2026, 1, 31, 23),
        DateTime(2026, 2, 1, 1),
      ),
      1,
    );
  });

  test('DST transitions do not truncate adjacent calendar days', () {
    final newYork = tz.getLocation('America/New_York');
    final beforeSpringForward = tz.TZDateTime(
      newYork,
      2026,
      DateTime.march,
      7,
      23,
      30,
    );
    final afterSpringForward = tz.TZDateTime(
      newYork,
      2026,
      DateTime.march,
      8,
      23,
      0,
    );
    final beforeFallBack = tz.TZDateTime(
      newYork,
      2026,
      DateTime.november,
      1,
      0,
      30,
    );
    final afterFallBack = tz.TZDateTime(
      newYork,
      2026,
      DateTime.november,
      2,
      0,
      15,
    );

    expect(CalendarDay.daysBetween(beforeSpringForward, afterSpringForward), 1);
    expect(CalendarDay.daysBetween(beforeFallBack, afterFallBack), 1);
  });

  test('future dates are clamped to the current local calendar day', () {
    final today = DateTime(2026, 7, 28, 15);

    expect(
      CalendarDay.clampToToday(DateTime(2026, 7, 29), today: today),
      DateTime(2026, 7, 28),
    );
    expect(
      CalendarDay.clampToToday(DateTime(2026, 7, 27), today: today),
      DateTime(2026, 7, 27),
    );
  });
}
