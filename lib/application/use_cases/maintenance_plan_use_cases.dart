import 'package:carvita/application/ports/maintenance_repository_port.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';

final class MaintenancePlanUseCases {
  const MaintenancePlanUseCases(this._repository);

  final MaintenanceRepositoryPort _repository;

  Future<List<MaintenancePlanItem>> getPlanItems(int vehicleId) {
    return _repository.getPlanItems(vehicleId);
  }

  Future<void> addPlanItem({
    required int vehicleId,
    required MaintenancePlanItem item,
  }) {
    _validateVehicle(vehicleId, item);
    return _repository.addPlanItem(item);
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
