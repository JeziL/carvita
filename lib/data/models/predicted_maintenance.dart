import 'package:equatable/equatable.dart';

import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/vehicle.dart';

enum PredictionBasis { time, mileage, timeAndMileageCombined, unknown }

class PredictedMaintenanceInfo extends Equatable {
  final Vehicle vehicle;
  final MaintenancePlanItem planItem;
  final DateTime predictedDueDate;
  final double? predictedAtMileage;
  final PredictionBasis basis; // prediction basis (time, mileage, or both)
  final bool isFirstOccurrence;
  final String notes;

  const PredictedMaintenanceInfo({
    required this.vehicle,
    required this.planItem,
    required this.predictedDueDate,
    this.predictedAtMileage,
    required this.basis,
    required this.isFirstOccurrence,
    required this.notes,
  });

  int compareTo(PredictedMaintenanceInfo other) {
    int dateComparison = predictedDueDate.compareTo(other.predictedDueDate);
    if (dateComparison != 0) {
      return dateComparison;
    }
    return planItem.itemName.compareTo(other.planItem.itemName);
  }

  @override
  List<Object?> get props => [
    vehicle.id,
    planItem.id,
    predictedDueDate,
    predictedAtMileage,
    basis,
    isFirstOccurrence,
  ];
}
