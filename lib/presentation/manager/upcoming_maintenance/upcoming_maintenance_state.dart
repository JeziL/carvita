import 'package:equatable/equatable.dart';

import 'package:carvita/core/failures/app_failure.dart';
import 'package:carvita/data/models/predicted_maintenance.dart';

abstract class UpcomingMaintenanceState extends Equatable {
  const UpcomingMaintenanceState();
  @override
  List<Object> get props => [];
}

class UpcomingMaintenanceInitial extends UpcomingMaintenanceState {}

class UpcomingMaintenanceLoading extends UpcomingMaintenanceState {}

class UpcomingMaintenanceLoaded extends UpcomingMaintenanceState {
  final List<PredictedMaintenanceInfo> allPredictions;
  // final Map<int, List<PredictedMaintenanceInfo>> predictionsByVehicleId;

  const UpcomingMaintenanceLoaded(this.allPredictions);
  @override
  List<Object> get props => [allPredictions];
}

class UpcomingMaintenanceError extends UpcomingMaintenanceState {
  final AppFailure failure;
  const UpcomingMaintenanceError(this.failure);
  @override
  List<Object> get props => [failure];
}
