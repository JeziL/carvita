import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:carvita/core/services/notification_coordinator.dart';
import 'package:carvita/core/services/prediction_service.dart';
import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/predicted_maintenance.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/service_log_performed_item_link.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'upcoming_maintenance_state.dart';

class UpcomingMaintenanceCubit extends Cubit<UpcomingMaintenanceState> {
  final VehicleRepository _vehicleRepository;
  final MaintenanceRepository _maintenanceRepository;
  final PredictionService _predictionService;
  final NotificationCoordinator _notificationCoordinator;
  final PreferencesService _preferencesService;
  final DateTime Function() _now;
  int _loadRevision = 0;
  final Map<int, Completer<void>> _loadWaiters = {};
  int _notificationRequestRevision = 0;
  final Map<int, Completer<void>> _notificationWaiters = {};
  _NotificationSyncInput? _latestNotificationInput;
  bool _isSynchronizingNotifications = false;

  UpcomingMaintenanceCubit(
    this._vehicleRepository,
    this._maintenanceRepository,
    this._predictionService,
    this._notificationCoordinator,
    this._preferencesService, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(UpcomingMaintenanceInitial());

  Future<void> loadAllUpcomingMaintenance(
    AppLocalizations? l10n, {
    Duration horizon = const Duration(days: 365),
  }) async {
    if (isClosed) return;
    final int loadRevision = ++_loadRevision;
    final loadCompleter = Completer<void>();
    _loadWaiters[loadRevision] = loadCompleter;
    final currentDate = _now();
    emit(UpcomingMaintenanceLoading());
    try {
      final List<Vehicle> vehicles = await _vehicleRepository.getVehicles();
      List<PredictedMaintenanceInfo> allPredictions = [];

      for (var vehicle in vehicles) {
        if (vehicle.id == null) continue;
        final List<MaintenancePlanItem> plans = await _maintenanceRepository
            .getPlanItems(vehicle.id!);
        final List<ServiceLogWithItems> logsWithItems =
            await _maintenanceRepository.getServiceLogs(vehicle.id!);

        // Convert ServiceLogWithItems to List<ServiceLogEntry> for MileageEstimator
        final List<ServiceLogEntry> serviceEntries = logsWithItems
            .map((lwi) => lwi.entry)
            .toList();

        // Fetch ServiceLogPerformedItemLink list
        final List<ServiceLogPerformedItemLink> performedItemLinks =
            await _maintenanceRepository.getPerformedItemLinksForVehicle(
              vehicle.id!,
            );

        final vehiclePredictions = _predictionService
            .getUpcomingServicesForVehicle(
              vehicle: vehicle,
              planItemsForVehicle: plans,
              allLogsForVehicle:
                  serviceEntries, // Pass all entries for rate calculation
              allPerformedItemsForVehicle: performedItemLinks,
              horizon: horizon,
              currentDateOverride: currentDate,
            );
        allPredictions.addAll(vehiclePredictions);
      }

      if (isClosed) {
        _completeLoadWaitersThrough(_loadRevision);
        return;
      }
      if (loadRevision != _loadRevision) {
        await loadCompleter.future;
        return;
      }

      allPredictions.sort((a, b) => a.compareTo(b)); // Sort all by due date
      emit(UpcomingMaintenanceLoaded(allPredictions));
      if (l10n != null) {
        try {
          await _scheduleNotifications(allPredictions, l10n);
        } catch (error, stackTrace) {
          debugPrint(
            'Failed to synchronize maintenance notifications: $error\n'
            '$stackTrace',
          );
        }
      }
      if (isClosed) {
        _completeLoadWaitersThrough(_loadRevision);
        return;
      }
      if (loadRevision != _loadRevision) {
        await loadCompleter.future;
        return;
      }
      _completeLoadWaitersThrough(loadRevision);
    } catch (error) {
      if (isClosed) {
        _completeLoadWaitersThrough(_loadRevision);
        return;
      }
      if (loadRevision != _loadRevision) {
        await loadCompleter.future;
        return;
      }
      emit(UpcomingMaintenanceError(error.toString()));
      _completeLoadWaitersThrough(loadRevision);
    }
  }

  void _completeLoadWaitersThrough(int loadRevision) {
    final completedRevisions = _loadWaiters.keys
        .where((revision) => revision <= loadRevision)
        .toList(growable: false);
    for (final revision in completedRevisions) {
      _loadWaiters.remove(revision)?.complete();
    }
  }

  Future<void> _scheduleNotifications(
    List<PredictedMaintenanceInfo> predictions,
    AppLocalizations l10n,
  ) {
    final int requestRevision = ++_notificationRequestRevision;
    final completer = Completer<void>();
    _notificationWaiters[requestRevision] = completer;
    _latestNotificationInput = _NotificationSyncInput(
      predictions: List<PredictedMaintenanceInfo>.unmodifiable(predictions),
      l10n: l10n,
    );

    if (!_isSynchronizingNotifications) {
      _isSynchronizingNotifications = true;
      unawaited(_drainNotificationSynchronization());
    }
    return completer.future;
  }

  Future<void> _drainNotificationSynchronization() async {
    while (true) {
      final int requestRevision = _notificationRequestRevision;
      final input = _latestNotificationInput!;

      try {
        final bool notificationsEnabled = await _preferencesService
            .getNotificationsEnabled();
        if (requestRevision != _notificationRequestRevision) continue;

        var requests = const <NotificationRequest>[];
        if (notificationsEnabled) {
          final int leadTimeDays = await _preferencesService
              .getReminderLeadTimeDays();
          if (requestRevision != _notificationRequestRevision) continue;

          final DateTime now = _now();
          requests = input.predictions
              .map((prediction) {
                final DateTime notificationTime = prediction.predictedDueDate
                    .subtract(Duration(days: leadTimeDays))
                    .copyWith(
                      hour: 12,
                      minute: 0,
                      second: 0,
                      millisecond: 0,
                      microsecond: 0,
                    );
                if (!notificationTime.isAfter(now)) return null;

                final int notificationId = maintenanceNotificationId(
                  vehicleId: prediction.vehicle.id!,
                  planItemId: prediction.planItem.id!,
                );
                return NotificationRequest(
                  id: notificationId,
                  title:
                      '${input.l10n.notificationPrefix}: '
                      '${prediction.vehicle.name}',
                  body: input.l10n.notificationBody(
                    prediction.planItem.itemName,
                    prediction.predictedDueDate,
                  ),
                  scheduledDateTime: notificationTime,
                  payload:
                      'vehicleId=${prediction.vehicle.id}'
                      '&planItemId=${prediction.planItem.id}'
                      '&scheduledDateTime=${notificationTime.toIso8601String()}',
                );
              })
              .whereType<NotificationRequest>()
              .toList(growable: false);
        }

        if (requestRevision != _notificationRequestRevision) continue;
        await _notificationCoordinator.replaceAll(requests);
        if (requestRevision != _notificationRequestRevision) continue;

        _completeNotificationWaitersThrough(requestRevision);
        _isSynchronizingNotifications = false;
        return;
      } catch (error, stackTrace) {
        if (requestRevision != _notificationRequestRevision) continue;
        _completeNotificationWaitersWithErrorThrough(
          requestRevision,
          error,
          stackTrace,
        );
        _isSynchronizingNotifications = false;
        return;
      }
    }
  }

  void _completeNotificationWaitersThrough(int requestRevision) {
    final completedRevisions = _notificationWaiters.keys
        .where((revision) => revision <= requestRevision)
        .toList(growable: false);
    for (final revision in completedRevisions) {
      _notificationWaiters.remove(revision)?.complete();
    }
  }

  void _completeNotificationWaitersWithErrorThrough(
    int requestRevision,
    Object error,
    StackTrace stackTrace,
  ) {
    final completedRevisions = _notificationWaiters.keys
        .where((revision) => revision <= requestRevision)
        .toList(growable: false);
    for (final revision in completedRevisions) {
      _notificationWaiters.remove(revision)?.completeError(error, stackTrace);
    }
  }

  Future<void> rescheduleNotificationsBasedOnNewSettings(
    AppLocalizations? l10n,
  ) async {
    if (state is UpcomingMaintenanceLoaded) {
      final currentPredictions =
          (state as UpcomingMaintenanceLoaded).allPredictions;
      if (l10n != null) {
        await _scheduleNotifications(currentPredictions, l10n);
      }
    } else {
      await loadAllUpcomingMaintenance(l10n);
    }
  }
}

final class _NotificationSyncInput {
  final List<PredictedMaintenanceInfo> predictions;
  final AppLocalizations l10n;

  const _NotificationSyncInput({required this.predictions, required this.l10n});
}
