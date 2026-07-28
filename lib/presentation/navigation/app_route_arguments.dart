import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_cubit.dart';
import 'package:carvita/presentation/manager/service_log/service_log_cubit.dart';

class AddEditVehicleRouteArguments {
  final Vehicle? vehicle;

  const AddEditVehicleRouteArguments({this.vehicle});
}

class VehicleDetailsRouteArguments {
  final int? vehicleId;

  const VehicleDetailsRouteArguments({required this.vehicleId});
}

class AddEditMaintenancePlanItemRouteArguments {
  final int vehicleId;
  final String vehicleName;
  final MaintenancePlanItem? planItem;
  final MaintenancePlanCubit maintenancePlanCubit;
  final ServiceLogCubit serviceLogCubit;

  const AddEditMaintenancePlanItemRouteArguments({
    required this.vehicleId,
    required this.vehicleName,
    this.planItem,
    required this.maintenancePlanCubit,
    required this.serviceLogCubit,
  });
}

class LogMaintenanceRouteArguments {
  final int vehicleId;
  final String vehicleName;
  final ServiceLogWithItems? logToEdit;
  final ServiceLogCubit serviceLogCubit;
  final MaintenancePlanCubit maintenancePlanCubit;

  const LogMaintenanceRouteArguments({
    required this.vehicleId,
    required this.vehicleName,
    this.logToEdit,
    required this.serviceLogCubit,
    required this.maintenancePlanCubit,
  });
}
