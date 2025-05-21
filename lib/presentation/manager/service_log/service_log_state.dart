import 'package:equatable/equatable.dart';

import 'package:carvita/data/models/service_log_entry.dart';

abstract class ServiceLogState extends Equatable {
  const ServiceLogState();

  @override
  List<Object> get props => [];
}

class ServiceLogInitial extends ServiceLogState {}

class ServiceLogLoading extends ServiceLogState {}

class ServiceLogLoaded extends ServiceLogState {
  final List<ServiceLogWithItems> serviceLogs;

  const ServiceLogLoaded(this.serviceLogs);

  @override
  List<Object> get props => [serviceLogs];
}

class ServiceLogError extends ServiceLogState {
  final String message;

  const ServiceLogError(this.message);

  @override
  List<Object> get props => [message];
}

class ServiceLogOperationSuccess extends ServiceLogState {
  final String message;
  const ServiceLogOperationSuccess(this.message);
  @override
  List<Object> get props => [message];
}
