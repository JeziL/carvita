import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;

import 'package:collection/collection.dart';
import 'package:quick_actions/quick_actions.dart';

import 'package:carvita/application/ports/preferences_ports.dart';
import 'package:carvita/application/ports/vehicle_repository_port.dart';
import 'package:carvita/data/models/vehicle.dart';

typedef ShortcutHandler = void Function(String shortcutType);

abstract interface class QuickActionPlatform {
  void initialize(ShortcutHandler onShortcut);

  Future<void> setShortcutItems({
    required String logMaintenanceTitle,
    required String upcomingMaintenanceTitle,
  });
}

class PluginQuickActionPlatform implements QuickActionPlatform {
  const PluginQuickActionPlatform();

  @override
  void initialize(ShortcutHandler onShortcut) {
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

abstract interface class QuickActionNavigation {
  bool get isReady;

  void openUpcomingMaintenance();

  void openLogMaintenance({
    required int vehicleId,
    required String vehicleName,
  });

  void openVehicleSelection(List<Vehicle> vehicles);

  void showNoVehicleMessage();
}

class QuickActionService {
  static const String logMaintenanceAction = 'action_log';
  static const String upcomingMaintenanceAction = 'action_upcoming_list';

  final VehicleRepositoryPort vehicleRepository;
  final DefaultVehiclePreferences preferencesService;
  final QuickActionPlatform platform;
  final QuickActionNavigation navigation;
  final Queue<String> _pendingActions = Queue<String>();
  String? _activeAction;
  bool _isDraining = false;

  QuickActionService({
    required this.vehicleRepository,
    required this.preferencesService,
    required this.navigation,
    required this.platform,
  });

  void initializeListener() {
    platform.initialize(_enqueueShortcut);
  }

  Future<void> updateShortcutItems({
    required String logMaintenanceTitle,
    required String upcomingMaintenanceTitle,
  }) {
    return platform.setShortcutItems(
      logMaintenanceTitle: logMaintenanceTitle,
      upcomingMaintenanceTitle: upcomingMaintenanceTitle,
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
    if (!navigation.isReady) return;

    _isDraining = true;
    try {
      while (_pendingActions.isNotEmpty) {
        if (!navigation.isReady) return;
        final action = _pendingActions.removeFirst();
        _activeAction = action;
        try {
          if (action == logMaintenanceAction) {
            await handleLogMaintenanceRequest();
          } else {
            navigation.openUpcomingMaintenance();
          }
        } catch (error, stackTrace) {
          assert(() {
            developer.log(
              'Failed to handle quick action $action',
              name: 'carvita.quick_actions',
              error: error,
              stackTrace: stackTrace,
            );
            return true;
          }());
        } finally {
          _activeAction = null;
        }
      }
    } finally {
      _isDraining = false;
    }
  }

  void _navigateToLogMaintenance(int vehicleId, String vehicleName) {
    navigation.openLogMaintenance(
      vehicleId: vehicleId,
      vehicleName: vehicleName,
    );
  }

  Future<void> handleLogMaintenanceRequest() async {
    final List<Vehicle> vehicles = await vehicleRepository.getVehicles();
    if (!navigation.isReady) return;

    if (vehicles.isEmpty) {
      navigation.showNoVehicleMessage();
    } else if (vehicles.length == 1) {
      _navigateToLogMaintenance(vehicles.first.id!, vehicles.first.name);
    } else {
      final defaultVehicleId = await preferencesService.getDefaultVehicleId();
      if (!navigation.isReady) return;
      if (defaultVehicleId != null) {
        final defaultVehicle = vehicles.firstWhereOrNull(
          (v) => v.id == defaultVehicleId,
        );
        if (defaultVehicle != null) {
          _navigateToLogMaintenance(defaultVehicle.id!, defaultVehicle.name);
          return;
        } else {
          await preferencesService.setDefaultVehicleId(null);
          if (!navigation.isReady) return;
        }
      }
      if (!navigation.isReady) return;
      navigation.openVehicleSelection(vehicles);
    }
  }
}
