import 'package:carvita/data/models/vehicle.dart';
import 'package:equatable/equatable.dart';

abstract class VehicleState extends Equatable {
  const VehicleState();

  @override
  List<Object> get props => [];
}

class VehicleInitial extends VehicleState {}

class VehicleLoading extends VehicleState {}

class VehicleLoaded extends VehicleState {
  final List<Vehicle> vehicles;

  const VehicleLoaded(this.vehicles);

  @override
  List<Object> get props => [vehicles];
}

class VehicleError extends VehicleState {
  final String message;

  const VehicleError(this.message);

  @override
  List<Object> get props => [message];
}

class VehicleOperationSuccess extends VehicleState {
  final String message;

  const VehicleOperationSuccess(this.message);

  @override
  List<Object> get props => [message];
}
