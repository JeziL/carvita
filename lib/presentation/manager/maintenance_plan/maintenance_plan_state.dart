import 'package:equatable/equatable.dart';

import 'package:carvita/core/failures/app_failure.dart';
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
  final AppFailure? refreshFailure;

  const MaintenancePlanLoaded(
    this.planItems, {
    this.isRefreshing = false,
    this.refreshFailure,
  });

  @override
  List<Object?> get props => [planItems, isRefreshing, refreshFailure];
}

class MaintenancePlanError extends MaintenancePlanState {
  final AppFailure failure;

  const MaintenancePlanError(this.failure);

  @override
  List<Object> get props => [failure];
}
