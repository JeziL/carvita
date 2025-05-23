import 'package:equatable/equatable.dart';

class ServiceLogPerformedItemLink extends Equatable {
  final int serviceLogId;
  final int maintenancePlanItemId;
  // final DateTime serviceLogDate; // maybe need this for sorting

  const ServiceLogPerformedItemLink({
    required this.serviceLogId,
    required this.maintenancePlanItemId,
    // required this.serviceLogDate,
  });

  @override
  List<Object?> get props => [serviceLogId, maintenancePlanItemId];
}
