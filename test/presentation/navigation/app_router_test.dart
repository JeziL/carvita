import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_cubit.dart';
import 'package:carvita/presentation/manager/service_log/service_log_cubit.dart';
import 'package:carvita/presentation/navigation/app_route_arguments.dart';
import 'package:carvita/presentation/navigation/app_router.dart';

void main() {
  late MaintenancePlanCubit maintenancePlanCubit;
  late ServiceLogCubit serviceLogCubit;

  setUp(() {
    final repository = MaintenanceRepository();
    maintenancePlanCubit = MaintenancePlanCubit(repository, 1);
    serviceLogCubit = ServiceLogCubit(repository, 1);
  });

  tearDown(() async {
    await maintenancePlanCubit.close();
    await serviceLogCubit.close();
  });

  test('parameterless routes preserve their RouteSettings', () {
    for (final routeName in [
      AppRoutes.dashboardRoute,
      AppRoutes.vehicleListRoute,
      AppRoutes.settingsRoute,
      AppRoutes.upcomingMaintenanceRoute,
      AppRoutes.privacyRoute,
    ]) {
      final settings = RouteSettings(name: routeName);

      final route = AppRouter.generateRoute(settings);

      expect(route.settings, same(settings));
    }
  });

  test('typed argument routes preserve their RouteSettings', () {
    final vehicle = Vehicle(
      id: 1,
      name: 'Test vehicle',
      mileage: 12000,
      mileageLastUpdated: DateTime(2024),
      boughtDate: DateTime(2024),
    );
    final routeSettings = [
      RouteSettings(
        name: AppRoutes.addVehicleRoute,
        arguments: AddEditVehicleRouteArguments(vehicle: vehicle),
      ),
      const RouteSettings(
        name: AppRoutes.vehicleDetailsRoute,
        arguments: VehicleDetailsRouteArguments(vehicleId: 1),
      ),
      RouteSettings(
        name: AppRoutes.addManualItemRoute,
        arguments: AddEditMaintenancePlanItemRouteArguments(
          vehicleId: 1,
          vehicleName: vehicle.name,
          maintenancePlanCubit: maintenancePlanCubit,
          serviceLogCubit: serviceLogCubit,
        ),
      ),
      RouteSettings(
        name: AppRoutes.logMaintenanceRoute,
        arguments: LogMaintenanceRouteArguments(
          vehicleId: 1,
          vehicleName: vehicle.name,
          serviceLogCubit: serviceLogCubit,
          maintenancePlanCubit: maintenancePlanCubit,
        ),
      ),
    ];

    for (final settings in routeSettings) {
      final route = AppRouter.generateRoute(settings);

      expect(route.settings, same(settings));
    }
  });

  test('existing missing-argument routes preserve their RouteSettings', () {
    for (final routeName in [
      AppRoutes.vehicleDetailsRoute,
      AppRoutes.addManualItemRoute,
      AppRoutes.logMaintenanceRoute,
      '/unknown',
    ]) {
      final settings = RouteSettings(name: routeName);

      final route = AppRouter.generateRoute(settings);

      expect(route.settings, same(settings));
    }
  });
}
