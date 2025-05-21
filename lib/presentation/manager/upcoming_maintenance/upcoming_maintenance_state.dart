import 'package:equatable/equatable.dart';

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
  final String message;
  const UpcomingMaintenanceError(this.message);
  @override
  List<Object> get props => [message];
}
