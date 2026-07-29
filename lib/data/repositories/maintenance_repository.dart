import 'package:carvita/application/ports/maintenance_repository_port.dart';
import 'package:carvita/application/ports/prediction_repository_port.dart';
import 'package:carvita/application/queries/maintenance_data_snapshot.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/service_log_performed_item_link.dart';
import 'package:carvita/data/sources/local/database_helper.dart';

class MaintenanceRepository
    implements MaintenanceRepositoryPort, PredictionRepositoryPort {
  final DatabaseHelper _dbHelper;

  MaintenanceRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper();

  // --- Maintenance Plan Methods ---
  @override
  Future<List<MaintenancePlanItem>> getPlanItems(int vehicleId) async {
    return await _dbHelper.getMaintenancePlanItemsForVehicle(vehicleId);
  }

  @override
  Future<void> addPlanItem(
    MaintenancePlanItem item, {
    required DateTime baselineDate,
  }) async {
    await _dbHelper.insertMaintenancePlanItem(
      item.copyWith(isActive: true),
      baselineDate: baselineDate,
    );
  }

  @override
  Future<void> updatePlanItem(MaintenancePlanItem item) async {
    await _dbHelper.updateMaintenancePlanItem(item);
  }

  @override
  Future<void> deletePlanItem(int itemId) async {
    await _dbHelper.softDeleteMaintenancePlanItem(itemId); // soft delete
  }

  // --- Service Log Methods ---
  @override
  Future<List<ServiceLogWithItems>> getServiceLogs(int vehicleId) async {
    return await _dbHelper.getServiceLogsWithItemsForVehicle(vehicleId);
  }

  @override
  Future<ServiceLogWithItems?> addServiceLog(
    ServiceLogEntry logEntry,
    List<PerformedItemInput> performedItems,
  ) async {
    return await _dbHelper.insertServiceLog(logEntry, performedItems);
  }

  @override
  Future<bool> updateServiceLog(
    ServiceLogEntry logEntry,
    List<PerformedItemInput> performedItems,
  ) async {
    final count = await _dbHelper.updateServiceLog(logEntry, performedItems);
    return count > 0;
  }

  @override
  Future<bool> deleteServiceLog(int logId) async {
    final count = await _dbHelper.deleteServiceLog(logId);
    return count > 0;
  }

  @override
  Future<List<ServiceLogPerformedItemLink>> getPerformedItemLinksForVehicle(
    int vehicleId,
  ) async {
    return await _dbHelper.getPerformedItemLinksForVehicle(vehicleId);
  }

  @override
  Future<MaintenanceDataSnapshot> getPredictionSnapshot() async {
    final rows = await _dbHelper.getPredictionSnapshotRows();
    return MaintenanceDataSnapshot(
      vehicles: rows.vehicles,
      planItems: rows.planItems,
      serviceLogs: rows.serviceLogs,
      performedItemLinks: rows.performedItemLinks,
    );
  }
}
