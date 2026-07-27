import 'package:equatable/equatable.dart';

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
  final String? refreshError;

  const VehicleLoaded(
    this.vehicles, {
    this.isRefreshing = false,
    this.refreshError,
  });

  @override
  List<Object?> get props => [vehicles, isRefreshing, refreshError];
}

class VehicleError extends VehicleState {
  final String message;

  const VehicleError(this.message);

  @override
  List<Object> get props => [message];
}
