abstract final class CalendarDay {
  static DateTime dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static int daysBetween(DateTime from, DateTime to) {
    final fromDay = DateTime.utc(from.year, from.month, from.day);
    final toDay = DateTime.utc(to.year, to.month, to.day);
    return toDay.difference(fromDay).inDays;
  }

  static int daysUntil(DateTime target, {DateTime? from}) {
    return daysBetween(from ?? DateTime.now(), target);
  }

  static bool isFuture(DateTime value, {DateTime? relativeTo}) {
    return daysBetween(relativeTo ?? DateTime.now(), value) > 0;
  }

  static DateTime clampToToday(DateTime value, {DateTime? today}) {
    final currentDay = dateOnly(today ?? DateTime.now());
    return isFuture(value, relativeTo: currentDay)
        ? currentDay
        : dateOnly(value);
  }
}
