import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/sources/local/database_helper.dart';

class MaintenanceRepository {
  final DatabaseHelper _dbHelper;

  MaintenanceRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  // --- Maintenance Plan Methods ---
  Future<List<MaintenancePlanItem>> getPlanItems(int vehicleId) async {
    return await _dbHelper.getMaintenancePlanItemsForVehicle(vehicleId);
  }

  Future<void> addPlanItem(MaintenancePlanItem item) async {
    await _dbHelper.insertMaintenancePlanItem(item.copyWith(isActive: true));
  }

  Future<void> updatePlanItem(MaintenancePlanItem item) async {
    await _dbHelper.updateMaintenancePlanItem(item);
  }

  Future<void> deletePlanItem(int itemId) async {
    await _dbHelper.softDeleteMaintenancePlanItem(itemId); // soft delete
  }

  // --- Service Log Methods ---
  Future<List<ServiceLogWithItems>> getServiceLogs(int vehicleId) async {
    return await _dbHelper.getServiceLogsWithItemsForVehicle(vehicleId);
  }

  Future<ServiceLogWithItems?> addServiceLog(ServiceLogEntry logEntry, List<PerformedItemInput> performedItems) async {
    return await _dbHelper.insertServiceLog(logEntry, performedItems);
  }

  Future<bool> updateServiceLog(ServiceLogEntry logEntry, List<PerformedItemInput> performedItems) async {
    final count = await _dbHelper.updateServiceLog(logEntry, performedItems);
    return count > 0;
  }

  Future<bool> deleteServiceLog(int logId) async {
    final count = await _dbHelper.deleteServiceLog(logId);
    return count > 0;
  }
}
