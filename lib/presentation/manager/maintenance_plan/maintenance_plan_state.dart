import 'package:equatable/equatable.dart';

import 'package:carvita/data/models/maintenance_plan_item.dart';

abstract class MaintenancePlanState extends Equatable {
  const MaintenancePlanState();

  @override
  List<Object?> get props => [];
}

class MaintenancePlanInitial extends MaintenancePlanState {}

class MaintenancePlanLoading extends MaintenancePlanState {}

class MaintenancePlanLoaded extends MaintenancePlanState {
  final List<MaintenancePlanItem> planItems;
  final bool isRefreshing;
  final String? refreshError;

  const MaintenancePlanLoaded(
    this.planItems, {
    this.isRefreshing = false,
    this.refreshError,
  });

  @override
  List<Object?> get props => [planItems, isRefreshing, refreshError];
}

class MaintenancePlanError extends MaintenancePlanState {
  final String message;

  const MaintenancePlanError(this.message);

  @override
  List<Object> get props => [message];
}
