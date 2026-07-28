import 'package:equatable/equatable.dart';

import 'package:carvita/core/failures/app_failure.dart';
import 'package:carvita/data/models/service_log_entry.dart';

abstract class ServiceLogState extends Equatable {
  const ServiceLogState();

  @override
  List<Object?> get props => [];
}

class ServiceLogInitial extends ServiceLogState {}

class ServiceLogLoading extends ServiceLogState {}

class ServiceLogLoaded extends ServiceLogState {
  final List<ServiceLogWithItems> serviceLogs;
  final bool isRefreshing;
  final AppFailure? refreshFailure;

  const ServiceLogLoaded(
    this.serviceLogs, {
    this.isRefreshing = false,
    this.refreshFailure,
  });

  @override
  List<Object?> get props => [serviceLogs, isRefreshing, refreshFailure];
}

class ServiceLogError extends ServiceLogState {
  final AppFailure failure;

  const ServiceLogError(this.failure);

  @override
  List<Object> get props => [failure];
}
