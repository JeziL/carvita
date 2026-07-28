import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/service_log_performed_item_link.dart';

abstract interface class MaintenanceRepositoryPort {
  Future<List<MaintenancePlanItem>> getPlanItems(int vehicleId);

  Future<void> addPlanItem(MaintenancePlanItem item);

  Future<void> updatePlanItem(MaintenancePlanItem item);

  Future<void> deletePlanItem(int itemId);

  Future<List<ServiceLogWithItems>> getServiceLogs(int vehicleId);

  Future<ServiceLogWithItems?> addServiceLog(
    ServiceLogEntry logEntry,
    List<PerformedItemInput> performedItems,
  );

  Future<bool> updateServiceLog(
    ServiceLogEntry logEntry,
    List<PerformedItemInput> performedItems,
  );

  Future<bool> deleteServiceLog(int logId);

  Future<List<ServiceLogPerformedItemLink>> getPerformedItemLinksForVehicle(
    int vehicleId,
  );
}
