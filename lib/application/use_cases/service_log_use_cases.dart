import 'package:carvita/application/ports/maintenance_repository_port.dart';
import 'package:carvita/data/models/service_log_entry.dart';

final class ServiceLogUseCases {
  const ServiceLogUseCases(this._repository);

  final MaintenanceRepositoryPort _repository;

  Future<List<ServiceLogWithItems>> getServiceLogs(int vehicleId) {
    return _repository.getServiceLogs(vehicleId);
  }

  Future<void> addServiceLog(
    ServiceLogEntry logEntry,
    List<PerformedItemInput> performedItems,
  ) async {
    final savedLog = await _repository.addServiceLog(logEntry, performedItems);
    if (savedLog == null) {
      throw StateError('Adding the service log did not return a saved record');
    }
  }

  Future<void> updateServiceLog(
    ServiceLogEntry logEntry,
    List<PerformedItemInput> performedItems,
  ) async {
    final updated = await _repository.updateServiceLog(
      logEntry,
      performedItems,
    );
    if (!updated) {
      throw StateError('Updating the service log affected no records');
    }
  }

  Future<void> deleteServiceLog(int logId) async {
    final deleted = await _repository.deleteServiceLog(logId);
    if (!deleted) {
      throw StateError('Deleting the service log affected no records');
    }
  }
}
