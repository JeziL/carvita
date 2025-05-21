import 'package:carvita/data/models/service_log_entry.dart';

class MileageEstimator {
  static const double defaultMonthlyMileage = 1666.6667; // default: 10000km in half year
  static const double defaultDailyMileage = defaultMonthlyMileage / 30.4375;

  // Calculate average daily mileage based on service logs
  static double getAverageDailyMileage(List<ServiceLogEntry> logs, {double fallback = defaultDailyMileage}) {
    if (logs.length < 2) {
      return fallback;
    }

    logs.sort((a, b) => a.serviceDate.compareTo(b.serviceDate));

    ServiceLogEntry? firstLog;
    ServiceLogEntry? lastLog;

    for (int i = 0; i < logs.length; i++) {
        if (logs[i].mileageAtService > 0) {
            firstLog = logs[i];
            break;
        }
    }

    for (int i = logs.length - 1; i >= 0; i--) {
        if (logs[i].mileageAtService > 0) {
            lastLog = logs[i];
            break;
        }
    }

    if (firstLog == null || lastLog == null || firstLog.id == lastLog.id || firstLog.mileageAtService >= lastLog.mileageAtService) {
      return fallback;
    }
    
    final double mileageDiff = lastLog.mileageAtService - firstLog.mileageAtService;
    final int daysDiff = lastLog.serviceDate.difference(firstLog.serviceDate).inDays;

    if (daysDiff <= 0 || mileageDiff <=0) {
      return fallback;
    }

    return mileageDiff / daysDiff;
  }

  // Predict the date when the target mileage will be reached
  static DateTime predictDateForTargetMileage({
    required double currentMileage,
    required double targetMileage,
    required double dailyRate,
    required DateTime fromDate,
  }) {
    if (dailyRate <= 0) {
        return DateTime.now().add(const Duration(days: 365 * 20)); // give a time in the far future
    }

    final double mileageToGo = targetMileage - currentMileage;
    final int daysNeeded = (mileageToGo / dailyRate).ceil();

    return fromDate.add(Duration(days: daysNeeded));
  }
}
