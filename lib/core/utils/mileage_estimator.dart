import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/vehicle.dart';

class MileageEstimator {
  static const double defaultDailyMileage =
      20000 / 365.2425; // default: 20000(km/mi) in a year

  // Calculate average daily mileage based on vehicle info and service logs
  static double getAverageDailyMileage(
    Vehicle vehicle,
    List<ServiceLogEntry> logs, {
    double fallback = defaultDailyMileage,
  }) {
    List<Map<String, dynamic>> entryList = [
      {'time': vehicle.mileageLastUpdated, 'mileage': vehicle.mileage},
    ];
    for (var log in logs) {
      if (log.mileageAtService > 0) {
        entryList.add({
          'time': log.serviceDate,
          'mileage': log.mileageAtService,
        });
      }
    }

    entryList.sort(
      (a, b) => (a['time'] as DateTime).compareTo((b['time'] as DateTime)),
    );

    if (entryList.length < 2) return fallback;
    if ((entryList.last['mileage'] as double) <=
        (entryList.first['mileage'] as double)) {
      return fallback;
    }

    final double mileageDiff =
        entryList.last['mileage'] - entryList.first['mileage'];
    final int daysDiff =
        (entryList.last['time'] as DateTime)
            .difference(entryList.first['time'])
            .inDays;

    if (daysDiff <= 0 || mileageDiff <= 0) {
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
      return DateTime.now().add(
        const Duration(days: 365 * 20),
      ); // give a time in the far future
    }

    final double mileageToGo = targetMileage - currentMileage;
    final int daysNeeded = (mileageToGo / dailyRate).ceil();

    return fromDate.add(Duration(days: daysNeeded));
  }
}
