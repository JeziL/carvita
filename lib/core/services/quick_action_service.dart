import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quick_actions/quick_actions.dart';

import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_cubit.dart';
import 'package:carvita/presentation/manager/service_log/service_log_cubit.dart';
import 'package:carvita/presentation/screens/maintenance/log_maintenance_screen.dart';
import 'package:carvita/presentation/screens/vehicle/select_vehicle_screen.dart';
import 'navigation_service.dart';

class QuickActionService {
  final VehicleRepository vehicleRepository;
  final MaintenanceRepository maintenanceRepository;
  final PreferencesService preferencesService;

  QuickActionService({
    required this.vehicleRepository,
    required this.maintenanceRepository,
    required this.preferencesService,
  });

  void initializeListener() {
    const QuickActions quickActions = QuickActions();

    quickActions.initialize((String shortcutType) {
      if (shortcutType == 'action_log') {
        handleLogMaintenanceRequest(NavigationService.currentContext);
      } else if (shortcutType == 'action_upcoming_list') {
        Navigator.pushNamedAndRemoveUntil(
          NavigationService.currentContext,
          AppRoutes.upcomingMaintenanceRoute,
          (_) => false,
        );
      }
    });
  }

  void updateShortcutItems(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const QuickActions quickActions = QuickActions();

    quickActions.setShortcutItems(<ShortcutItem>[
      ShortcutItem(
        type: 'action_log',
        localizedTitle: l10n.logMaintenance,
        icon: 'ic_launcher',
      ),
      ShortcutItem(
        type: 'action_upcoming_list',
        localizedTitle: l10n.upcomingMaintenance,
        icon: 'ic_launcher',
      ),
    ]);
  }

  void _navigateToLogMaintenance(
    BuildContext context,
    int vehicleId,
    String vehicleName,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (newRouteContext) => MultiBlocProvider(
              providers: [
                BlocProvider(
                  create:
                      (_) =>
                          MaintenancePlanCubit(maintenanceRepository, vehicleId)
                            ..fetchPlanItems(),
                ),
                BlocProvider(
                  create:
                      (_) =>
                          ServiceLogCubit(maintenanceRepository, vehicleId)
                            ..fetchServiceLogs(),
                ),
              ],
              child: LogMaintenanceScreen(
                vehicleId: vehicleId,
                vehicleName: vehicleName,
                logToEdit: null,
              ),
            ),
      ),
    );
  }

  Future<void> handleLogMaintenanceRequest(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<Vehicle> vehicles = await vehicleRepository.getVehicles();

    if (vehicles.isEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errNoVehicleToLog),
          backgroundColor: AppColors.urgentReminderText,
        ),
      );
    } else if (vehicles.length == 1 && context.mounted) {
      _navigateToLogMaintenance(
        context,
        vehicles.first.id!,
        vehicles.first.name,
      );
    } else {
      final defaultVehicleId = await preferencesService.getDefaultVehicleId();
      if (defaultVehicleId != null) {
        final defaultVehicle = vehicles.firstWhereOrNull(
          (v) => v.id == defaultVehicleId,
        );
        if (defaultVehicle != null && context.mounted) {
          _navigateToLogMaintenance(
            context,
            defaultVehicle.id!,
            defaultVehicle.name,
          );
          return;
        } else {
          await preferencesService.setDefaultVehicleId(null);
        }
      }
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SelectVehicleScreen(vehicles: vehicles),
          ),
        );
      }
    }
  }
}
