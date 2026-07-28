import 'package:carvita/application/ports/clock.dart';
import 'package:carvita/application/ports/prediction_repository_port.dart';
import 'package:carvita/core/services/prediction_service.dart';
import 'package:carvita/data/models/predicted_maintenance.dart';

final class LoadUpcomingMaintenance {
  const LoadUpcomingMaintenance(
    this._predictionRepository,
    this._predictionService,
    this._clock,
  );

  final PredictionRepositoryPort _predictionRepository;
  final PredictionService _predictionService;
  final Clock _clock;

  Future<List<PredictedMaintenanceInfo>> call({
    Duration horizon = const Duration(days: 365),
  }) async {
    final currentDate = _clock.now();
    final snapshot = await _predictionRepository.getPredictionSnapshot();
    final allPredictions = <PredictedMaintenanceInfo>[];

    for (final vehicle in snapshot.vehicles) {
      final vehicleId = vehicle.id;
      if (vehicleId == null) continue;

      final plans = snapshot.planItemsByVehicleId[vehicleId] ?? const [];
      final logs = snapshot.serviceLogsByVehicleId[vehicleId] ?? const [];
      final performedItemLinks =
          snapshot.performedItemLinksByVehicleId[vehicleId] ?? const [];

      allPredictions.addAll(
        _predictionService.getUpcomingServicesForVehicle(
          vehicle: vehicle,
          planItemsForVehicle: plans,
          allLogsForVehicle: logs,
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
