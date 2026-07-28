import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;

import 'package:carvita/application/ports/maintenance_repository_port.dart';
import 'package:carvita/application/ports/notification_tap_port.dart';
import 'package:carvita/application/ports/vehicle_repository_port.dart';
import 'package:carvita/application/reminders/maintenance_reminder_payload.dart';

abstract interface class MaintenanceReminderNavigation {
  bool get isReady;

  void openVehicleMaintenancePlan(int vehicleId);

  void openUpcomingMaintenance();
}

class MaintenanceReminderTapService implements NotificationTapPort {
  MaintenanceReminderTapService(
    this._vehicleRepository,
    this._maintenanceRepository,
    this._navigation,
  );

  static const int _maximumConsumedKeys = 64;

  final VehicleRepositoryPort _vehicleRepository;
  final MaintenanceRepositoryPort _maintenanceRepository;
  final MaintenanceReminderNavigation _navigation;
  final Queue<MaintenanceReminderPayload> _pendingPayloads =
      Queue<MaintenanceReminderPayload>();
  final Set<String> _pendingKeys = {};
  final Set<String> _consumedKeys = {};
  final Queue<String> _consumedKeyOrder = Queue<String>();

  String? _activeKey;
  bool _isDraining = false;

  @override
  void enqueuePayload(String? payload) {
    final parsed = MaintenanceReminderPayload.tryParse(payload);
    if (parsed == null) return;

    final key = parsed.deduplicationKey;
    if (_activeKey == key ||
        _pendingKeys.contains(key) ||
        _consumedKeys.contains(key)) {
      return;
    }

    _pendingPayloads.add(parsed);
    _pendingKeys.add(key);
    unawaited(_drainPendingPayloads());
  }

  @override
  void navigatorReady() {
    unawaited(_drainPendingPayloads());
  }

  Future<void> _drainPendingPayloads() async {
    if (_isDraining || !_navigation.isReady) return;

    _isDraining = true;
    try {
      while (_pendingPayloads.isNotEmpty) {
        if (!_navigation.isReady) return;

        final payload = _pendingPayloads.removeFirst();
        final key = payload.deduplicationKey;
        _pendingKeys.remove(key);
        _activeKey = key;
        try {
          final handled = await _handlePayload(payload);
          if (!handled) {
            _pendingPayloads.addFirst(payload);
            _pendingKeys.add(key);
            return;
          }
          _rememberConsumed(key);
        } catch (error, stackTrace) {
          assert(() {
            developer.log(
              'Failed to handle a maintenance reminder tap',
              name: 'carvita.reminders',
              error: error,
              stackTrace: stackTrace,
            );
            return true;
          }());
        } finally {
          _activeKey = null;
        }
      }
    } finally {
      _isDraining = false;
    }
  }

  Future<bool> _handlePayload(MaintenanceReminderPayload payload) async {
    final vehicle = await _vehicleRepository.getVehicleById(payload.vehicleId);
    if (!_navigation.isReady) return false;
    if (vehicle == null) {
      _navigation.openUpcomingMaintenance();
      return true;
    }

    final planItems = await _maintenanceRepository.getPlanItems(
      payload.vehicleId,
    );
    if (!_navigation.isReady) return false;

    final targetExists = planItems.any(
      (item) => item.id == payload.planItemId && item.isActive,
    );
    if (targetExists) {
      _navigation.openVehicleMaintenancePlan(payload.vehicleId);
    } else {
      _navigation.openUpcomingMaintenance();
    }
    return true;
  }

  void _rememberConsumed(String key) {
    if (!_consumedKeys.add(key)) return;
    _consumedKeyOrder.add(key);
    while (_consumedKeyOrder.length > _maximumConsumedKeys) {
      _consumedKeys.remove(_consumedKeyOrder.removeFirst());
    }
  }
}
