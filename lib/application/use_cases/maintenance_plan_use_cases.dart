import 'package:carvita/application/ports/maintenance_repository_port.dart';
import 'package:carvita/application/ports/clock.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';

final class MaintenancePlanUseCases {
  const MaintenancePlanUseCases(
    this._repository, [
    this._clock = const SystemClock(),
  ]);

  final MaintenanceRepositoryPort _repository;
  final Clock _clock;

  Future<List<MaintenancePlanItem>> getPlanItems(int vehicleId) {
    return _repository.getPlanItems(vehicleId);
  }

  Future<void> addPlanItem({
    required int vehicleId,
    required MaintenancePlanItem item,
  }) {
    _validateVehicle(vehicleId, item);
    final now = _clock.now();
    return _repository.addPlanItem(
      item,
      baselineDate: DateTime(now.year, now.month, now.day),
    );
  }

  Future<void> updatePlanItem({
    required int vehicleId,
    required MaintenancePlanItem item,
  }) {
    _validateVehicle(vehicleId, item);
    return _repository.updatePlanItem(item);
  }

  Future<void> deletePlanItem(int itemId) {
    return _repository.deletePlanItem(itemId);
  }

  void _validateVehicle(int vehicleId, MaintenancePlanItem item) {
    if (item.vehicleId != vehicleId) {
      throw ArgumentError.value(
        item.vehicleId,
        'item.vehicleId',
        'Vehicle does not match maintenance plan',
      );
    }
  }
}
