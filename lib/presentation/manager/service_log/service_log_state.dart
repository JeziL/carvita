import 'package:equatable/equatable.dart';

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
  final String? refreshError;

  const ServiceLogLoaded(
    this.serviceLogs, {
    this.isRefreshing = false,
    this.refreshError,
  });

  @override
  List<Object?> get props => [serviceLogs, isRefreshing, refreshError];
}

class ServiceLogError extends ServiceLogState {
  final String message;

  const ServiceLogError(this.message);

  @override
  List<Object> get props => [message];
}
