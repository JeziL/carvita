import 'package:carvita/application/ports/clock.dart';
import 'package:carvita/core/utils/mileage_estimator.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/predicted_maintenance.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/service_log_performed_item_link.dart';
import 'package:carvita/data/models/vehicle.dart';

class PredictionService {
  const PredictionService(this._clock);

  final Clock _clock;

  /// Calculate the next service date for an item.
  PredictedMaintenanceInfo? calculateNextServiceForItem({
    required Vehicle vehicle,
    required MaintenancePlanItem planItem,
    required List<ServiceLogEntry>
    allLogsForVehicle, // all logs for this vehicle
    required List<ServiceLogPerformedItemLink>
    allPerformedItemsForVehicle, // utility data structure
    DateTime? currentDateOverride, // For testing
  }) {
    // 1. Look for the last service log entry for this planItem on this vehicle
    ServiceLogEntry? lastServiceLogForItem;
    final logsById = {
      for (final log in allLogsForVehicle)
        if (log.id != null) log.id!: log,
    };
    for (final link in allPerformedItemsForVehicle) {
      if (link.maintenancePlanItemId != planItem.id) continue;
      final candidate = logsById[link.serviceLogId];
      if (candidate == null) continue;
      final current = lastServiceLogForItem;
      if (current == null ||
          candidate.serviceDate.isAfter(current.serviceDate) ||
          (candidate.serviceDate == current.serviceDate &&
              (candidate.id ?? -1) > (current.id ?? -1))) {
        lastServiceLogForItem = candidate;
      }
    }

    DateTime? nextDateByTime;
    DateTime? nextDateByMileage;
    double? targetMileageForPrediction;
    String timeNotes = "";
    String mileageNotes = "";
    bool isFirst = false;

    double vehicleDailyRate = MileageEstimator.getAverageDailyMileage(
      vehicle,
      allLogsForVehicle,
    );

    if (lastServiceLogForItem == null) {
      isFirst = true;
      final baselineDate = planItem.baselineDate ?? vehicle.boughtDate;
      final baselineMileage = planItem.baselineMileage ?? 0;
      if (planItem.hasFirstInterval) {
        if (planItem.firstIntervalTimeMonths != null) {
          nextDateByTime = _addMonths(
            baselineDate,
            planItem.firstIntervalTimeMonths!,
          );
          timeNotes = "first time period (from plan baseline)";
        }
        if (planItem.firstIntervalMileage != null) {
          targetMileageForPrediction =
              baselineMileage + planItem.firstIntervalMileage!;
          nextDateByMileage = MileageEstimator.predictDateForTargetMileage(
            currentMileage: vehicle.mileage,
            targetMileage: targetMileageForPrediction,
            dailyRate: vehicleDailyRate,
            fromDate: currentDateOverride ?? vehicle.mileageLastUpdated,
          );
          mileageNotes = "first mileage period (from plan baseline)";
        }
      } else {
        if (planItem.intervalTimeMonths != null) {
          nextDateByTime = _addMonths(
            baselineDate,
            planItem.intervalTimeMonths!,
          );
          timeNotes = "general time period (from plan baseline)";
        }
        if (planItem.intervalMileage != null) {
          targetMileageForPrediction =
              baselineMileage + planItem.intervalMileage!;
          nextDateByMileage = MileageEstimator.predictDateForTargetMileage(
            currentMileage: vehicle.mileage,
            targetMileage: targetMileageForPrediction,
            dailyRate: vehicleDailyRate,
            fromDate: currentDateOverride ?? vehicle.mileageLastUpdated,
          );
          mileageNotes = "general mileage period (from plan baseline)";
        }
      }
    } else {
      isFirst = false;
      if (planItem.intervalTimeMonths != null) {
        nextDateByTime = _addMonths(
          lastServiceLogForItem.serviceDate,
          planItem.intervalTimeMonths!,
        );
        timeNotes = "general time period";
      }
      if (planItem.intervalMileage != null) {
        targetMileageForPrediction =
            lastServiceLogForItem.mileageAtService + planItem.intervalMileage!;
        nextDateByMileage = MileageEstimator.predictDateForTargetMileage(
          currentMileage: vehicle.mileage,
          targetMileage: targetMileageForPrediction,
          dailyRate: vehicleDailyRate,
          fromDate: currentDateOverride ?? vehicle.mileageLastUpdated,
        );
        mileageNotes = "general mileage period";
      }
    }

    if (nextDateByTime != null && nextDateByMileage != null) {
      if (nextDateByTime.isBefore(nextDateByMileage)) {
        return PredictedMaintenanceInfo(
          vehicle: vehicle,
          planItem: planItem,
          predictedDueDate: nextDateByTime,
          predictedAtMileage: targetMileageForPrediction,
          basis: PredictionBasis.timeAndMileageCombined,
          isFirstOccurrence: isFirst,
          notes: "$timeNotes takes precedence",
        );
      } else {
        return PredictedMaintenanceInfo(
          vehicle: vehicle,
          planItem: planItem,
          predictedDueDate: nextDateByMileage,
          predictedAtMileage: targetMileageForPrediction,
          basis: PredictionBasis.timeAndMileageCombined,
          isFirstOccurrence: isFirst,
          notes: "$mileageNotes takes precedence",
        );
      }
    } else if (nextDateByTime != null) {
      return PredictedMaintenanceInfo(
        vehicle: vehicle,
        planItem: planItem,
        predictedDueDate: nextDateByTime,
        basis: PredictionBasis.time,
        isFirstOccurrence: isFirst,
        notes: timeNotes,
      );
    } else if (nextDateByMileage != null) {
      return PredictedMaintenanceInfo(
        vehicle: vehicle,
        planItem: planItem,
        predictedDueDate: nextDateByMileage,
        predictedAtMileage: targetMileageForPrediction,
        basis: PredictionBasis.mileage,
        isFirstOccurrence: isFirst,
        notes: mileageNotes,
      );
    }

    return null;
  }

  /// Get all upcoming service predictions for a vehicle within a specific time horizon
  List<PredictedMaintenanceInfo> getUpcomingServicesForVehicle({
    required Vehicle vehicle,
    required List<MaintenancePlanItem> planItemsForVehicle,
    required List<ServiceLogEntry> allLogsForVehicle,
    required List<ServiceLogPerformedItemLink>
    allPerformedItemsForVehicle, // utility data structure
    Duration horizon = const Duration(days: 365), // 1 year by default
    DateTime? currentDateOverride,
  }) {
    final DateTime now = currentDateOverride ?? _clock.now();
    final DateTime endDate = now.add(horizon);
    List<PredictedMaintenanceInfo> predictions = [];

    for (var planItem in planItemsForVehicle) {
      if (!planItem.isActive) continue; // omit soft-deleted items

      final prediction = calculateNextServiceForItem(
        vehicle: vehicle,
        planItem: planItem,
        allLogsForVehicle: allLogsForVehicle,
        allPerformedItemsForVehicle: allPerformedItemsForVehicle,
        currentDateOverride: currentDateOverride,
      );
      if (prediction != null &&
          !prediction.predictedDueDate.isAfter(
            endDate,
          ) /* && prediction.predictedDueDate.isAfter(now.subtract(const Duration(days: 180)))*/ ) {
        // maybe omit items that are too old?
        predictions.add(prediction);
      }
    }
    predictions.sort((a, b) => a.compareTo(b));
    return predictions;
  }

  // Add months to a date, handling year-end carry
  DateTime _addMonths(DateTime date, int months) {
    var newYear = date.year + (date.month + months - 1) ~/ 12;
    var newMonth = (date.month + months - 1) % 12 + 1;
    var newDay = date.day;

    var daysInNewMonth = _daysInMonth(newYear, newMonth);
    if (newDay > daysInNewMonth) {
      newDay = daysInNewMonth;
    }
    return DateTime(
      newYear,
      newMonth,
      newDay,
      date.hour,
      date.minute,
      date.second,
    );
  }

  int _daysInMonth(int year, int month) {
    final firstDayOfFollowingMonth = month == DateTime.december
        ? DateTime(year + 1)
        : DateTime(year, month + 1);
    return firstDayOfFollowingMonth.subtract(const Duration(days: 1)).day;
  }
}
