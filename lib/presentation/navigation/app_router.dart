import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_cubit.dart';
import 'package:carvita/presentation/manager/service_log/service_log_cubit.dart';
import 'package:carvita/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:carvita/presentation/screens/maintenance/add_edit_maintenance_plan_item_screen.dart';
import 'package:carvita/presentation/screens/maintenance/log_maintenance_screen.dart';
import 'package:carvita/presentation/screens/maintenance/upcoming_maintenance_list_screen.dart';
import 'package:carvita/presentation/screens/settings/privacy_screen.dart';
import 'package:carvita/presentation/screens/settings/settings_screen.dart';
import 'package:carvita/presentation/screens/vehicle/add_edit_vehicle_screen.dart';
import 'package:carvita/presentation/screens/vehicle/vehicle_list_screen.dart';
import 'package:carvita/presentation/screens/vehicle/vehicle_details_screen.dart';
import 'package:carvita/core/constants/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.dashboardRoute:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case AppRoutes.vehicleListRoute:
        return MaterialPageRoute(builder: (_) => const VehicleListScreen());
      case AppRoutes.settingsRoute:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case AppRoutes.upcomingMaintenanceRoute:
        return MaterialPageRoute(
          builder: (_) => const UpcomingMaintenanceListScreen(),
        );
      case AppRoutes.privacyRoute:
        return MaterialPageRoute(builder: (_) => const PrivacyScreen());
      case AppRoutes.addVehicleRoute:
        final vehicleToEdit = settings.arguments as Vehicle?;
        return MaterialPageRoute(
          builder: (_) => AddEditVehicleScreen(vehicle: vehicleToEdit),
        );
      case AppRoutes.vehicleDetailsRoute:
        final vehicleId = settings.arguments as int?;
        if (vehicleId != null) {
          return MaterialPageRoute(
            builder: (_) => VehicleDetailsScreen(vehicleId: vehicleId),
          );
        }
        return _errorRoute("Vehicle ID missing for vehicleDetailsRoute");
      case AppRoutes.addManualItemRoute:
        final arguments = settings.arguments as Map<String, dynamic>?;
        final int? vehicleId = arguments?['vehicleId'] as int?;
        final String? vehicleName = arguments?['vehicleName'] as String?;
        final MaintenancePlanItem? planItem =
            arguments?['planItem'] as MaintenancePlanItem?;
        final MaintenancePlanCubit? cubitInstance =
            arguments?['cubitInstance'] as MaintenancePlanCubit?;

        if (vehicleId != null && cubitInstance != null && vehicleName != null) {
          return MaterialPageRoute(
            builder:
                (_) => BlocProvider.value(
                  value: cubitInstance,
                  child: AddEditMaintenancePlanItemScreen(
                    vehicleId: vehicleId,
                    planItemToEdit: planItem,
                    vehicleName: vehicleName,
                  ),
                ),
          );
        }
        return _errorRoute(
          "Vehicle ID missing for add/edit maintenance plan item",
        );
      case AppRoutes.logMaintenanceRoute:
        final arguments = settings.arguments as Map<String, dynamic>?;
        final int? vehicleId = arguments?['vehicleId'] as int?;
        final String? vehicleName = arguments?['vehicleName'] as String?;
        final ServiceLogWithItems? logToEdit =
            arguments?['logToEdit'] as ServiceLogWithItems?;
        final ServiceLogCubit serviceLogCubit =
            arguments?['serviceLogCubit'] as ServiceLogCubit;
        final MaintenancePlanCubit maintenancePlanCubit =
            arguments?['maintenancePlanCubit'] as MaintenancePlanCubit;

        if (vehicleId != null && vehicleName != null) {
          return MaterialPageRoute(
            builder:
                (_) => MultiBlocProvider(
                  providers: [
                    BlocProvider.value(value: serviceLogCubit),
                    BlocProvider.value(value: maintenancePlanCubit),
                  ],
                  child: LogMaintenanceScreen(
                    vehicleId: vehicleId,
                    vehicleName: vehicleName,
                    logToEdit: logToEdit,
                  ),
                ),
          );
        }
        return _errorRoute("Missing arguments for LogMaintenanceScreen");
      default:
        return _errorRoute("No route defined for ${settings.name}");
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder:
          (_) => Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text(message)),
          ),
    );
  }
}
