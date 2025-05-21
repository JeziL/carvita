import 'dart:async';
import 'package:carvita/core/services/notification_service.dart';
import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/predicted_maintenance.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'package:carvita/core/services/prediction_service.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_cubit.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_state.dart' as vehicle_list_state_import;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'upcoming_maintenance_state.dart';
import 'package:carvita/data/sources/local/database_helper.dart';

class UpcomingMaintenanceCubit extends Cubit<UpcomingMaintenanceState> {
  final VehicleRepository _vehicleRepository;
  final MaintenanceRepository _maintenanceRepository;
  final PredictionService _predictionService;
  final DatabaseHelper _dbHelper; // Temporary for getPerformedItemLinksForVehicle, ideally through repo
  final VehicleCubit _vehicleCubit;
  late StreamSubscription _vehicleCubitSubscription;
  final NotificationService _notificationService;
  final PreferencesService _preferencesService;
  final BuildContext _context;

  UpcomingMaintenanceCubit(
    this._vehicleRepository,
    this._maintenanceRepository,
    this._predictionService,
    this._dbHelper, // Pass dbHelper or refactor link fetching into repo
    this._vehicleCubit,
    this._notificationService,
    this._preferencesService,
    this._context,
  ) : super(UpcomingMaintenanceInitial()) {
    _vehicleCubitSubscription = _vehicleCubit.stream.listen((vehicleState) {
      if (vehicleState is vehicle_list_state_import.VehicleLoaded || 
          vehicleState is vehicle_list_state_import.VehicleOperationSuccess) {
        loadAllUpcomingMaintenance();
      }
    });
  }

  Future<void> loadAllUpcomingMaintenance({Duration horizon = const Duration(days: 365)}) async {
    emit(UpcomingMaintenanceLoading());
    try {
      final List<Vehicle> vehicles = await _vehicleRepository.getVehicles();
      List<PredictedMaintenanceInfo> allPredictions = [];

      for (var vehicle in vehicles) {
        if (vehicle.id == null) continue;
        final List<MaintenancePlanItem> plans = await _maintenanceRepository.getPlanItems(vehicle.id!);
        final List<ServiceLogWithItems> logsWithItems = await _maintenanceRepository.getServiceLogs(vehicle.id!);
        
        // Convert ServiceLogWithItems to List<ServiceLogEntry> for MileageEstimator
        final List<ServiceLogEntry> serviceEntries = logsWithItems.map((lwi) => lwi.entry).toList();

        // Fetch or construct ServiceLogPerformedItemLink list
        // This is a simplified placeholder for getting the link data.
        // MaintenanceRepository should provide this efficiently.
        final List<ServiceLogPerformedItemLink> performedItemLinks = await _dbHelper.getPerformedItemLinksForVehicle(vehicle.id!);


        final vehiclePredictions = _predictionService.getUpcomingServicesForVehicle(
          vehicle: vehicle,
          planItemsForVehicle: plans,
          allLogsForVehicle: serviceEntries, // Pass all entries for rate calculation
          allPerformedItemsForVehicle: performedItemLinks,
          horizon: horizon,
        );
        allPredictions.addAll(vehiclePredictions);
      }

      allPredictions.sort((a, b) => a.compareTo(b)); // Sort all by due date
      emit(UpcomingMaintenanceLoaded(allPredictions));
      await _scheduleNotifications(allPredictions);
    } catch (e) {
      emit(UpcomingMaintenanceError(e.toString()));
    }
  }

  Future<void> _scheduleNotifications(List<PredictedMaintenanceInfo> predictions) async {
    await _notificationService.cancelAllNotifications();

    final bool notificationsEnabled = await _preferencesService.getNotificationsEnabled();
    if (!notificationsEnabled) {
      return;
    }

    final int leadTimeDays = await _preferencesService.getReminderLeadTimeDays();

    for (var prediction in predictions) {
      DateTime notificationTime = prediction.predictedDueDate.subtract(Duration(days: leadTimeDays)).copyWith(
        hour: 12,
        minute: 0,
        second: 0,
        millisecond: 0,
        microsecond: 0,
      );

      final DateTime now = DateTime.now();
      if (notificationTime.isAfter(now) && _context.mounted) {
        String title = "${AppLocalizations.of(_context)!.notificationPrefix}: ${prediction.vehicle.name}";
        String body = AppLocalizations.of(_context)!.notificationBody(prediction.planItem.itemName, prediction.predictedDueDate);

        int notificationId = "${prediction.vehicle.id!}|${prediction.planItem.id!}".hashCode;

        await _notificationService.scheduleNotification(
          id: notificationId,
          title: title,
          body: body,
          scheduledDateTime: notificationTime,
          payload: 'vehicleId=${prediction.vehicle.id}&planItemId=${prediction.planItem.id}&scheduledDateTime=${notificationTime.toIso8601String()}',
        );
      }
    }
    _notificationService.checkPendingNotifications(); // for debugging
  }

  Future<void> rescheduleNotificationsBasedOnNewSettings() async {
    if (state is UpcomingMaintenanceLoaded) {
      final currentPredictions = (state as UpcomingMaintenanceLoaded).allPredictions;
      await _scheduleNotifications(currentPredictions);
    } else {
      loadAllUpcomingMaintenance();
    }
  }

  @override
  Future<void> close() {
    _vehicleCubitSubscription.cancel();
    return super.close();
  }
}
