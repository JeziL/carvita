import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/service_log_performed_item_link.dart';
import 'package:carvita/data/models/vehicle.dart';

/// A consistent, read-only set of maintenance inputs used by one prediction
/// refresh.
final class MaintenanceDataSnapshot {
  MaintenanceDataSnapshot({
    required Iterable<Vehicle> vehicles,
    required Iterable<MaintenancePlanItem> planItems,
    required Iterable<ServiceLogEntry> serviceLogs,
    required Iterable<ServiceLogPerformedItemLink> performedItemLinks,
  }) : vehicles = List<Vehicle>.unmodifiable(vehicles),
       planItemsByVehicleId = _groupByVehicle(
         planItems,
         (item) => item.vehicleId,
       ),
       serviceLogsByVehicleId = _groupByVehicle(
         serviceLogs,
         (log) => log.vehicleId,
       ),
       performedItemLinksByVehicleId = _groupLinksByVehicle(
         serviceLogs,
         performedItemLinks,
       );

  final List<Vehicle> vehicles;
  final Map<int, List<MaintenancePlanItem>> planItemsByVehicleId;
  final Map<int, List<ServiceLogEntry>> serviceLogsByVehicleId;
  final Map<int, List<ServiceLogPerformedItemLink>>
  performedItemLinksByVehicleId;

  static Map<int, List<T>> _groupByVehicle<T>(
    Iterable<T> values,
    int Function(T value) vehicleIdOf,
  ) {
    final grouped = <int, List<T>>{};
    for (final value in values) {
      grouped.putIfAbsent(vehicleIdOf(value), () => <T>[]).add(value);
    }
    return Map<int, List<T>>.unmodifiable({
      for (final entry in grouped.entries)
        entry.key: List<T>.unmodifiable(entry.value),
    });
  }

  static Map<int, List<ServiceLogPerformedItemLink>> _groupLinksByVehicle(
    Iterable<ServiceLogEntry> serviceLogs,
    Iterable<ServiceLogPerformedItemLink> links,
  ) {
    final vehicleIdByLogId = <int, int>{
      for (final log in serviceLogs)
        if (log.id case final int logId) logId: log.vehicleId,
    };
    final grouped = <int, List<ServiceLogPerformedItemLink>>{};
    for (final link in links) {
      final vehicleId = vehicleIdByLogId[link.serviceLogId];
      if (vehicleId == null) continue;
      grouped
          .putIfAbsent(vehicleId, () => <ServiceLogPerformedItemLink>[])
          .add(link);
    }
    return Map<int, List<ServiceLogPerformedItemLink>>.unmodifiable({
      for (final entry in grouped.entries)
        entry.key: List<ServiceLogPerformedItemLink>.unmodifiable(entry.value),
    });
  }
}
