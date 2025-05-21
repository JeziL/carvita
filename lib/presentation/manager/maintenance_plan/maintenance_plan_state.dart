import 'package:equatable/equatable.dart';

import 'package:carvita/data/models/maintenance_plan_item.dart';

abstract class MaintenancePlanState extends Equatable {
  const MaintenancePlanState();

  @override
  List<Object> get props => [];
}

class MaintenancePlanInitial extends MaintenancePlanState {}

class MaintenancePlanLoading extends MaintenancePlanState {}

class MaintenancePlanLoaded extends MaintenancePlanState {
  final List<MaintenancePlanItem> planItems;

  const MaintenancePlanLoaded(this.planItems);

  @override
  List<Object> get props => [planItems];
}

class MaintenancePlanError extends MaintenancePlanState {
  final String message;

  const MaintenancePlanError(this.message);

  @override
  List<Object> get props => [message];
}

class MaintenancePlanOperationSuccess extends MaintenancePlanState {
  final String message;
  const MaintenancePlanOperationSuccess(this.message);
  @override
  List<Object> get props => [message];
}
