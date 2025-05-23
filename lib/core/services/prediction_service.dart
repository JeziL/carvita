import 'package:flutter/material.dart';

import 'package:collection/collection.dart';

import 'package:carvita/core/utils/mileage_estimator.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/predicted_maintenance.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/service_log_performed_item_link.dart';
import 'package:carvita/data/models/vehicle.dart';

class PredictionService {
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
    final DateTime now = currentDateOverride ?? DateTime.now();

    // 1. Look for the last service log entry for this planItem on this vehicle
    ServiceLogEntry? lastServiceLogForItem;
    // Find all performedItem records for this planItem
    final performedInstancesOfThisItem =
        allPerformedItemsForVehicle
            .where((link) => link.maintenancePlanItemId == planItem.id)
            .toList();

    if (performedInstancesOfThisItem.isNotEmpty) {
      // Find the latest serviceLogId from these performedItem records
      performedInstancesOfThisItem.sort((a, b) {
        final logA = allLogsForVehicle.firstWhereOrNull(
          (log) => log.id == a.serviceLogId,
        );
        final logB = allLogsForVehicle.firstWhereOrNull(
          (log) => log.id == b.serviceLogId,
        );
        if (logA == null && logB == null) return 0;
        if (logA == null) return 1; // Put nulls last
        if (logB == null) return -1;
        return logB.serviceDate.compareTo(
          logA.serviceDate,
        ); // Sort descending by date
      });

      if (performedInstancesOfThisItem.isNotEmpty) {
        final latestPerformedLink = performedInstancesOfThisItem.first;
        lastServiceLogForItem = allLogsForVehicle.firstWhereOrNull(
          (log) => log.id == latestPerformedLink.serviceLogId,
        );
      }
    }

    DateTime? nextDateByTime;
    DateTime? nextDateByMileage;
    double? targetMileageForPrediction;
    String timeNotes = "";
    String mileageNotes = "";
    bool isFirst = false;

    double vehicleDailyRate = MileageEstimator.getAverageDailyMileage(
      allLogsForVehicle,
    );

    if (lastServiceLogForItem == null) {
      isFirst = true;
      if (planItem.hasFirstInterval) {
        if (planItem.firstIntervalTimeMonths != null) {
          nextDateByTime = _addMonths(
            vehicle.boughtDate,
            planItem.firstIntervalTimeMonths!,
          );
          timeNotes = "first time period";
        }
        if (planItem.firstIntervalMileage != null) {
          targetMileageForPrediction =
              planItem.firstIntervalMileage!.toDouble();
          nextDateByMileage = MileageEstimator.predictDateForTargetMileage(
            currentMileage: vehicle.mileage,
            targetMileage: targetMileageForPrediction,
            dailyRate: vehicleDailyRate,
            fromDate: now,
          );
          mileageNotes = "first mileage period";
        }
      } else {
        if (planItem.intervalTimeMonths != null) {
          nextDateByTime = _addMonths(
            vehicle.boughtDate,
            planItem.intervalTimeMonths!,
          );
          timeNotes = "general time period (from purchase date)";
        }
        if (planItem.intervalMileage != null) {
          targetMileageForPrediction = planItem.intervalMileage!.toDouble();
          nextDateByMileage = MileageEstimator.predictDateForTargetMileage(
            currentMileage: vehicle.mileage,
            targetMileage: targetMileageForPrediction,
            dailyRate: vehicleDailyRate,
            fromDate: now,
          );
          mileageNotes = "general mileage period (from purchase date)";
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
          fromDate: now,
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
    final DateTime now = currentDateOverride ?? DateTime.now();
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

    var daysInNewMonth = DateUtils.getDaysInMonth(newYear, newMonth);
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
}
