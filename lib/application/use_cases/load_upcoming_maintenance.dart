import 'package:carvita/application/ports/clock.dart';
import 'package:carvita/application/ports/maintenance_repository_port.dart';
import 'package:carvita/application/ports/vehicle_repository_port.dart';
import 'package:carvita/core/services/prediction_service.dart';
import 'package:carvita/data/models/predicted_maintenance.dart';

final class LoadUpcomingMaintenance {
  const LoadUpcomingMaintenance(
    this._vehicleRepository,
    this._maintenanceRepository,
    this._predictionService,
    this._clock,
  );

  final VehicleRepositoryPort _vehicleRepository;
  final MaintenanceRepositoryPort _maintenanceRepository;
  final PredictionService _predictionService;
  final Clock _clock;

  Future<List<PredictedMaintenanceInfo>> call({
    Duration horizon = const Duration(days: 365),
  }) async {
    final currentDate = _clock.now();
    final vehicles = await _vehicleRepository.getVehicles();
    final allPredictions = <PredictedMaintenanceInfo>[];

    for (final vehicle in vehicles) {
      final vehicleId = vehicle.id;
      if (vehicleId == null) continue;

      final plans = await _maintenanceRepository.getPlanItems(vehicleId);
      final logsWithItems = await _maintenanceRepository.getServiceLogs(
        vehicleId,
      );
      final performedItemLinks = await _maintenanceRepository
          .getPerformedItemLinksForVehicle(vehicleId);

      allPredictions.addAll(
        _predictionService.getUpcomingServicesForVehicle(
          vehicle: vehicle,
          planItemsForVehicle: plans,
          allLogsForVehicle: logsWithItems
              .map((logWithItems) => logWithItems.entry)
              .toList(growable: false),
          allPerformedItemsForVehicle: performedItemLinks,
          horizon: horizon,
          currentDateOverride: currentDate,
        ),
      );
    }

    allPredictions.sort((first, second) => first.compareTo(second));
    return allPredictions;
  }
}
