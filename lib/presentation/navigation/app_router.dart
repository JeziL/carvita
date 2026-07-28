import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/presentation/navigation/app_route_arguments.dart';
import 'package:carvita/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:carvita/presentation/screens/maintenance/add_edit_maintenance_plan_item_screen.dart';
import 'package:carvita/presentation/screens/maintenance/log_maintenance_screen.dart';
import 'package:carvita/presentation/screens/maintenance/upcoming_maintenance_list_screen.dart';
import 'package:carvita/presentation/screens/settings/privacy_screen.dart';
import 'package:carvita/presentation/screens/settings/settings_screen.dart';
import 'package:carvita/presentation/screens/vehicle/add_edit_vehicle_screen.dart';
import 'package:carvita/presentation/screens/vehicle/vehicle_details_screen.dart';
import 'package:carvita/presentation/screens/vehicle/vehicle_list_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.dashboardRoute:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const DashboardScreen(),
        );
      case AppRoutes.vehicleListRoute:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const VehicleListScreen(),
        );
      case AppRoutes.settingsRoute:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SettingsScreen(),
        );
      case AppRoutes.upcomingMaintenanceRoute:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const UpcomingMaintenanceListScreen(),
        );
      case AppRoutes.privacyRoute:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const PrivacyScreen(),
        );
      case AppRoutes.addVehicleRoute:
        final arguments = settings.arguments as AddEditVehicleRouteArguments?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AddEditVehicleScreen(vehicle: arguments?.vehicle),
        );
      case AppRoutes.vehicleDetailsRoute:
        final arguments = settings.arguments as VehicleDetailsRouteArguments?;
        if (arguments?.vehicleId != null) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) =>
                VehicleDetailsScreen(vehicleId: arguments!.vehicleId!),
          );
        }
        return _errorRoute(
          settings,
          "Vehicle ID missing for vehicleDetailsRoute",
        );
      case AppRoutes.addManualItemRoute:
        final arguments =
            settings.arguments as AddEditMaintenancePlanItemRouteArguments?;

        if (arguments != null) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: arguments.maintenancePlanCubit),
                BlocProvider.value(value: arguments.serviceLogCubit),
              ],
              child: AddEditMaintenancePlanItemScreen(
                vehicleId: arguments.vehicleId,
                planItemToEdit: arguments.planItem,
                vehicleName: arguments.vehicleName,
              ),
            ),
          );
        }
        return _errorRoute(
          settings,
          "Vehicle ID missing for add/edit maintenance plan item",
        );
      case AppRoutes.logMaintenanceRoute:
        final arguments = settings.arguments as LogMaintenanceRouteArguments?;

        if (arguments != null) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: arguments.serviceLogCubit),
                BlocProvider.value(value: arguments.maintenancePlanCubit),
              ],
              child: LogMaintenanceScreen(
                vehicleId: arguments.vehicleId,
                vehicleName: arguments.vehicleName,
                logToEdit: arguments.logToEdit,
              ),
            ),
          );
        }
        return _errorRoute(
          settings,
          "Missing arguments for LogMaintenanceScreen",
        );
      default:
        return _errorRoute(settings, "No route defined for ${settings.name}");
    }
  }

  static Route<dynamic> _errorRoute(RouteSettings settings, String message) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(message)),
      ),
    );
  }
}
