import 'dart:async';
import 'dart:collection';

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

abstract interface class QuickActionPlatform {
  void initialize(ValueChanged<String> onShortcut);

  Future<void> setShortcutItems({
    required String logMaintenanceTitle,
    required String upcomingMaintenanceTitle,
  });
}

class PluginQuickActionPlatform implements QuickActionPlatform {
  const PluginQuickActionPlatform();

  @override
  void initialize(ValueChanged<String> onShortcut) {
    const QuickActions().initialize(onShortcut);
  }

  @override
  Future<void> setShortcutItems({
    required String logMaintenanceTitle,
    required String upcomingMaintenanceTitle,
  }) {
    return const QuickActions().setShortcutItems([
      ShortcutItem(
        type: QuickActionService.logMaintenanceAction,
        localizedTitle: logMaintenanceTitle,
        icon: 'ic_action_log',
      ),
      ShortcutItem(
        type: QuickActionService.upcomingMaintenanceAction,
        localizedTitle: upcomingMaintenanceTitle,
        icon: 'ic_action_list',
      ),
    ]);
  }
}

class QuickActionService {
  static const String logMaintenanceAction = 'action_log';
  static const String upcomingMaintenanceAction = 'action_upcoming_list';

  final VehicleRepository vehicleRepository;
  final MaintenanceRepository maintenanceRepository;
  final PreferencesService preferencesService;
  final QuickActionPlatform platform;
  final BuildContext? Function() _navigatorContextProvider;
  final Queue<String> _pendingActions = Queue<String>();
  String? _activeAction;
  bool _isDraining = false;

  QuickActionService({
    required this.vehicleRepository,
    required this.maintenanceRepository,
    required this.preferencesService,
    this.platform = const PluginQuickActionPlatform(),
    BuildContext? Function()? navigatorContextProvider,
  }) : _navigatorContextProvider =
           navigatorContextProvider ??
           (() => NavigationService.navigatorKey.currentContext);

  void initializeListener() {
    platform.initialize(_enqueueShortcut);
  }

  Future<void> updateShortcutItems(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return platform.setShortcutItems(
      logMaintenanceTitle: l10n.logMaintenance,
      upcomingMaintenanceTitle: l10n.upcomingMaintenance,
    );
  }

  void navigatorReady() {
    unawaited(_drainPendingActions());
  }

  void _enqueueShortcut(String shortcutType) {
    if (shortcutType != logMaintenanceAction &&
        shortcutType != upcomingMaintenanceAction) {
      return;
    }
    if (_activeAction == shortcutType ||
        _pendingActions.contains(shortcutType)) {
      return;
    }
    _pendingActions.add(shortcutType);
    unawaited(_drainPendingActions());
  }

  Future<void> _drainPendingActions() async {
    if (_isDraining) return;
    final initialContext = _navigatorContextProvider();
    if (initialContext == null || !initialContext.mounted) return;

    _isDraining = true;
    try {
      while (_pendingActions.isNotEmpty) {
        final context = _navigatorContextProvider();
        if (context == null || !context.mounted) return;
        final action = _pendingActions.removeFirst();
        _activeAction = action;
        try {
          if (action == logMaintenanceAction) {
            await handleLogMaintenanceRequest(context);
          } else {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.upcomingMaintenanceRoute,
              (_) => false,
            );
          }
        } catch (error, stackTrace) {
          debugPrint(
            'Failed to handle quick action $action: $error\n$stackTrace',
          );
        } finally {
          _activeAction = null;
        }
      }
    } finally {
      _isDraining = false;
    }
  }

  void _navigateToLogMaintenance(
    BuildContext context,
    int vehicleId,
    String vehicleName,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (newRouteContext) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  MaintenancePlanCubit(maintenanceRepository, vehicleId)
                    ..fetchPlanItems(),
            ),
            BlocProvider(
              create: (_) =>
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
    if (!context.mounted) return;

    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errNoVehicleToLog),
          backgroundColor: AppColors.urgentReminderText,
        ),
      );
    } else if (vehicles.length == 1) {
      _navigateToLogMaintenance(
        context,
        vehicles.first.id!,
        vehicles.first.name,
      );
    } else {
      final defaultVehicleId = await preferencesService.getDefaultVehicleId();
      if (!context.mounted) return;
      if (defaultVehicleId != null) {
        final defaultVehicle = vehicles.firstWhereOrNull(
          (v) => v.id == defaultVehicleId,
        );
        if (defaultVehicle != null) {
          _navigateToLogMaintenance(
            context,
            defaultVehicle.id!,
            defaultVehicle.name,
          );
          return;
        } else {
          await preferencesService.setDefaultVehicleId(null);
          if (!context.mounted) return;
        }
      }
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SelectVehicleScreen(vehicles: vehicles),
        ),
      );
    }
  }
}
