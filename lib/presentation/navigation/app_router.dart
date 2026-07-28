import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/navigation/app_route_arguments.dart';
import 'package:carvita/presentation/screens/maintenance/add_edit_maintenance_plan_item_screen.dart';
import 'package:carvita/presentation/screens/maintenance/log_maintenance_screen.dart';
import 'package:carvita/presentation/navigation/main_shell.dart';
import 'package:carvita/presentation/screens/settings/privacy_screen.dart';
import 'package:carvita/presentation/screens/vehicle/add_edit_vehicle_screen.dart';
import 'package:carvita/presentation/screens/vehicle/vehicle_details_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.dashboardRoute:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MainShell(),
        );
      case AppRoutes.vehicleListRoute:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MainShell(initialIndex: 1),
        );
      case AppRoutes.settingsRoute:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MainShell(initialIndex: 3),
        );
      case AppRoutes.upcomingMaintenanceRoute:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MainShell(initialIndex: 2),
        );
      case AppRoutes.privacyRoute:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const PrivacyScreen(),
        );
      case AppRoutes.addVehicleRoute:
        final arguments = settings.arguments;
        if (arguments != null && arguments is! AddEditVehicleRouteArguments) {
          return _errorRoute(settings);
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AddEditVehicleScreen(
            vehicle: (arguments as AddEditVehicleRouteArguments?)?.vehicle,
          ),
        );
      case AppRoutes.vehicleDetailsRoute:
        final arguments = settings.arguments;
        if (arguments is VehicleDetailsRouteArguments &&
            arguments.vehicleId != null) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => VehicleDetailsScreen(
              vehicleId: arguments.vehicleId!,
              initialTab: arguments.initialTab,
            ),
          );
        }
        return _errorRoute(settings);
      case AppRoutes.addManualItemRoute:
        final arguments = settings.arguments;

        if (arguments is AddEditMaintenancePlanItemRouteArguments) {
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
        return _errorRoute(settings);
      case AppRoutes.logMaintenanceRoute:
        final arguments = settings.arguments;

        if (arguments is LogMaintenanceRouteArguments) {
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
        return _errorRoute(settings);
      default:
        return _errorRoute(settings);
    }
  }

  static Route<dynamic> _errorRoute(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final navigator = Navigator.of(context);
        return Scaffold(
          appBar: AppBar(title: Text(l10n.routeErrorTitle)),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.routeErrorMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (navigator.canPop())
                          OutlinedButton(
                            onPressed: navigator.pop,
                            child: Text(l10n.back),
                          ),
                        FilledButton(
                          onPressed: () {
                            navigator.pushNamedAndRemoveUntil(
                              AppRoutes.dashboardRoute,
                              (_) => false,
                            );
                          },
                          child: Text(l10n.goToHome),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
