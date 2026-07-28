import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:carvita/application/use_cases/maintenance_plan_use_cases.dart';
import 'package:carvita/application/use_cases/service_log_use_cases.dart';
import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/services/navigation_service.dart';
import 'package:carvita/core/services/quick_action_service.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_cubit.dart';
import 'package:carvita/presentation/manager/service_log/service_log_cubit.dart';
import 'package:carvita/presentation/navigation/main_navigation_controller.dart';
import 'package:carvita/presentation/screens/maintenance/log_maintenance_screen.dart';
import 'package:carvita/presentation/screens/vehicle/select_vehicle_screen.dart';

class DefaultQuickActionNavigation implements QuickActionNavigation {
  final MaintenancePlanUseCases _maintenancePlanUseCases;
  final ServiceLogUseCases _serviceLogUseCases;
  final MainNavigationController _mainNavigation;

  const DefaultQuickActionNavigation(
    this._maintenancePlanUseCases,
    this._serviceLogUseCases,
    this._mainNavigation,
  );

  BuildContext? get _context => NavigationService.navigatorKey.currentContext;

  @override
  bool get isReady => _context?.mounted ?? false;

  @override
  void openUpcomingMaintenance() {
    final context = _context;
    if (context == null || !context.mounted) return;
    final navigator = NavigationService.navigatorKey.currentState;
    if (navigator == null) return;
    _mainNavigation.revealRootTab(navigator, 2);
  }

  @override
  void openLogMaintenance({
    required int vehicleId,
    required String vehicleName,
  }) {
    final context = _context;
    if (context == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  MaintenancePlanCubit(_maintenancePlanUseCases, vehicleId)
                    ..fetchPlanItems(),
            ),
            BlocProvider(
              create: (_) =>
                  ServiceLogCubit(_serviceLogUseCases, vehicleId)
                    ..fetchServiceLogs(),
            ),
          ],
          child: LogMaintenanceScreen(
            vehicleId: vehicleId,
            vehicleName: vehicleName,
          ),
        ),
      ),
    );
  }

  @override
  void openVehicleSelection(List<Vehicle> vehicles) {
    final context = _context;
    if (context == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SelectVehicleScreen(vehicles: vehicles),
      ),
    );
  }

  @override
  void showNoVehicleMessage() {
    final context = _context;
    if (context == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.errNoVehicleToLog),
        backgroundColor: AppColors.urgentReminderText,
      ),
    );
  }
}
