import 'package:equatable/equatable.dart';

import 'package:carvita/core/failures/app_failure.dart';
import 'package:carvita/data/models/vehicle.dart';

abstract class VehicleState extends Equatable {
  const VehicleState();

  @override
  List<Object?> get props => [];
}

class VehicleInitial extends VehicleState {}

class VehicleLoading extends VehicleState {}

class VehicleLoaded extends VehicleState {
  final List<Vehicle> vehicles;
  final bool isRefreshing;
  final AppFailure? refreshFailure;

  const VehicleLoaded(
    this.vehicles, {
    this.isRefreshing = false,
    this.refreshFailure,
  });

  @override
  List<Object?> get props => [vehicles, isRefreshing, refreshFailure];
}

class VehicleError extends VehicleState {
  final AppFailure failure;

  const VehicleError(this.failure);

  @override
  List<Object> get props => [failure];
}
