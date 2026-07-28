import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/application/ports/maintenance_repository_port.dart';
import 'package:carvita/application/ports/vehicle_repository_port.dart';
import 'package:carvita/application/reminders/maintenance_reminder_payload.dart';
import 'package:carvita/core/services/maintenance_reminder_tap_service.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/service_log_performed_item_link.dart';
import 'package:carvita/data/models/vehicle.dart';

void main() {
  final payload = MaintenanceReminderPayload(
    vehicleId: 1,
    planItemId: 10,
    scheduledAt: _scheduledAt,
  );

  test('queues a cold-start tap until navigation is ready', () async {
    final navigation = _FakeNavigation();
    final service = _service(navigation: navigation);

    service.enqueuePayload(payload.encode());
    await pumpEventQueue();
    expect(navigation.events, isEmpty);

    navigation.ready = true;
    service.navigatorReady();
    await pumpEventQueue();

    expect(navigation.events, ['plan:1']);
  });

  test('foreground and resume callbacks consume the same tap once', () async {
    final navigation = _FakeNavigation()..ready = true;
    final service = _service(navigation: navigation);
    final encoded = payload.encode();

    service.enqueuePayload(encoded);
    service.enqueuePayload(encoded);
    await pumpEventQueue();
    service.enqueuePayload(encoded);
    await pumpEventQueue();

    expect(navigation.events, ['plan:1']);
  });

  test('a later reminder occurrence for the same plan can be opened', () async {
    final navigation = _FakeNavigation()..ready = true;
    final service = _service(navigation: navigation);

    service.enqueuePayload(payload.encode());
    await pumpEventQueue();
    service.enqueuePayload(
      MaintenanceReminderPayload(
        vehicleId: 1,
        planItemId: 10,
        scheduledAt: _scheduledAt.add(const Duration(days: 30)),
      ).encode(),
    );
    await pumpEventQueue();

    expect(navigation.events, ['plan:1', 'plan:1']);
  });

  test('a deleted vehicle opens the upcoming list', () async {
    final navigation = _FakeNavigation()..ready = true;
    final service = _service(
      navigation: navigation,
      vehicleRepository: _FakeVehicleRepository(vehicleExists: false),
    );

    service.enqueuePayload(payload.encode());
    await pumpEventQueue();

    expect(navigation.events, ['upcoming']);
  });

  test('a deleted or inactive plan opens the upcoming list', () async {
    for (final plans in [
      const <MaintenancePlanItem>[],
      const [
        MaintenancePlanItem(
          id: 10,
          vehicleId: 1,
          itemName: 'Oil',
          isActive: false,
        ),
      ],
    ]) {
      final navigation = _FakeNavigation()..ready = true;
      final service = _service(
        navigation: navigation,
        maintenanceRepository: _FakeMaintenanceRepository(plans: plans),
      );

      service.enqueuePayload(payload.encode());
      await pumpEventQueue();

      expect(navigation.events, ['upcoming']);
    }
  });

  test('malformed and malicious payloads are ignored', () async {
    final navigation = _FakeNavigation()..ready = true;
    final vehicles = _FakeVehicleRepository();
    final service = _service(
      navigation: navigation,
      vehicleRepository: vehicles,
    );

    service.enqueuePayload('vehicleId=1&planItemId=10');
    service.enqueuePayload(
      '{"payloadVersion":1,"action":"deleteEverything",'
      '"vehicleId":1,"planItemId":10,"scheduledAtEpochMillis":1}',
    );
    await pumpEventQueue();

    expect(navigation.events, isEmpty);
    expect(vehicles.readCount, 0);
  });

  test('a transient validation failure can be retried safely', () async {
    final navigation = _FakeNavigation()..ready = true;
    final vehicles = _FakeVehicleRepository()..failNextRead = true;
    final service = _service(
      navigation: navigation,
      vehicleRepository: vehicles,
    );
    final encoded = payload.encode();

    service.enqueuePayload(encoded);
    await pumpEventQueue();
    expect(navigation.events, isEmpty);

    service.enqueuePayload(encoded);
    await pumpEventQueue();
    expect(navigation.events, ['plan:1']);
  });
}

final _scheduledAt = DateTime.utc(2030, 1, 2, 12);

MaintenanceReminderTapService _service({
  required _FakeNavigation navigation,
  _FakeVehicleRepository? vehicleRepository,
  _FakeMaintenanceRepository? maintenanceRepository,
}) {
  return MaintenanceReminderTapService(
    vehicleRepository ?? _FakeVehicleRepository(),
    maintenanceRepository ?? _FakeMaintenanceRepository(),
    navigation,
  );
}

Vehicle _vehicle() {
  return Vehicle(
    id: 1,
    name: 'Vehicle',
    mileage: 1000,
    mileageLastUpdated: DateTime(2026, 7, 27),
    boughtDate: DateTime(2026, 1, 1),
  );
}

class _FakeNavigation implements MaintenanceReminderNavigation {
  bool ready = false;
  final List<String> events = [];

  @override
  bool get isReady => ready;

  @override
  void openUpcomingMaintenance() {
    events.add('upcoming');
  }

  @override
  void openVehicleMaintenancePlan(int vehicleId) {
    events.add('plan:$vehicleId');
  }
}

class _FakeVehicleRepository implements VehicleRepositoryPort {
  _FakeVehicleRepository({bool vehicleExists = true})
    : vehicle = vehicleExists ? _vehicle() : null;

  final Vehicle? vehicle;
  bool failNextRead = false;
  int readCount = 0;

  @override
  Future<Vehicle?> getVehicleById(int id) async {
    readCount++;
    if (failNextRead) {
      failNextRead = false;
      throw StateError('temporary database failure');
    }
    return vehicle;
  }

  @override
  Future<List<Vehicle>> getVehicles() async => [if (vehicle != null) vehicle!];

  @override
  Future<void> addVehicle(Vehicle vehicle) async {}

  @override
  Future<void> deleteVehicle(int id) async {}

  @override
  Future<void> updateVehicle(Vehicle vehicle) async {}
}

class _FakeMaintenanceRepository implements MaintenanceRepositoryPort {
  _FakeMaintenanceRepository({
    this.plans = const [
      MaintenancePlanItem(id: 10, vehicleId: 1, itemName: 'Oil'),
    ],
  });

  final List<MaintenancePlanItem> plans;

  @override
  Future<List<MaintenancePlanItem>> getPlanItems(int vehicleId) async => plans;

  @override
  Future<void> addPlanItem(MaintenancePlanItem item) async {}

  @override
  Future<void> deletePlanItem(int itemId) async {}

  @override
  Future<bool> deleteServiceLog(int logId) async => true;

  @override
  Future<List<ServiceLogPerformedItemLink>> getPerformedItemLinksForVehicle(
    int vehicleId,
  ) async => const [];

  @override
  Future<List<ServiceLogWithItems>> getServiceLogs(int vehicleId) async =>
      const [];

  @override
  Future<ServiceLogWithItems?> addServiceLog(
    ServiceLogEntry logEntry,
    List<PerformedItemInput> performedItems,
  ) async => null;

  @override
  Future<bool> updateServiceLog(
    ServiceLogEntry logEntry,
    List<PerformedItemInput> performedItems,
  ) async => true;

  @override
  Future<void> updatePlanItem(MaintenancePlanItem item) async {}
}
