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
  int _loadRevision = 0;
  int _notificationRequestRevision = 0;

  UpcomingMaintenanceCubit(
    this._vehicleRepository,
    this._maintenanceRepository,
    this._predictionService,
    this._notificationCoordinator,
    this._preferencesService,
  ) : super(UpcomingMaintenanceInitial());

  Future<void> loadAllUpcomingMaintenance(
    AppLocalizations? l10n, {
    Duration horizon = const Duration(days: 365),
  }) async {
    final int loadRevision = ++_loadRevision;
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
        final List<ServiceLogEntry> serviceEntries =
            logsWithItems.map((lwi) => lwi.entry).toList();

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
            );
        allPredictions.addAll(vehiclePredictions);
      }

      if (loadRevision != _loadRevision || isClosed) return;

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
    } catch (e) {
      if (loadRevision != _loadRevision || isClosed) return;
      emit(UpcomingMaintenanceError(e.toString()));
    }
  }

  Future<void> _scheduleNotifications(
    List<PredictedMaintenanceInfo> predictions,
    AppLocalizations l10n,
  ) async {
    final int requestRevision = ++_notificationRequestRevision;

    final bool notificationsEnabled =
        await _preferencesService.getNotificationsEnabled();
    if (requestRevision != _notificationRequestRevision) return;

    if (!notificationsEnabled) {
      await _notificationCoordinator.replaceAll(const []);
      return;
    }

    final int leadTimeDays =
        await _preferencesService.getReminderLeadTimeDays();
    if (requestRevision != _notificationRequestRevision) return;

    final DateTime now = DateTime.now();
    final List<NotificationRequest> requests = predictions
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
            title: '${l10n.notificationPrefix}: ${prediction.vehicle.name}',
            body: l10n.notificationBody(
              prediction.planItem.itemName,
              prediction.predictedDueDate,
            ),
            scheduledDateTime: notificationTime,
            payload:
                'vehicleId=${prediction.vehicle.id}&planItemId=${prediction.planItem.id}&scheduledDateTime=${notificationTime.toIso8601String()}',
          );
        })
        .whereType<NotificationRequest>()
        .toList(growable: false);

    if (requestRevision != _notificationRequestRevision) return;
    await _notificationCoordinator.replaceAll(requests);
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
