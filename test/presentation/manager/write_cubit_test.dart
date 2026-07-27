import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/core/utils/operation_result.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_cubit.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_state.dart';
import 'package:carvita/presentation/manager/service_log/service_log_cubit.dart';
import 'package:carvita/presentation/manager/service_log/service_log_state.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_cubit.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_state.dart';

void main() {
  group('VehicleCubit write protocol', () {
    test('waits for refresh before returning success', () async {
      final repository = _FakeVehicleRepository([_vehicle(id: 1)]);
      final cubit = VehicleCubit(repository);
      await cubit.fetchVehicles();
      final emitted = <VehicleState>[];
      final subscription = cubit.stream.listen(emitted.add);

      final result = await cubit.addVehicle(_vehicle(id: 2));
      await Future<void>.delayed(Duration.zero);

      expect(result, isA<OperationSuccess>());
      expect(repository.events, ['getVehicles', 'addVehicle', 'getVehicles']);
      expect(emitted, [
        VehicleLoaded([_vehicle(id: 1)], isRefreshing: true),
        VehicleLoaded([_vehicle(id: 1), _vehicle(id: 2)]),
      ]);
      await subscription.cancel();
      await cubit.close();
    });

    test('write failure keeps the last successful data', () async {
      final repository = _FakeVehicleRepository([_vehicle(id: 1)])
        ..writeError = StateError('write failed');
      final cubit = VehicleCubit(repository);
      await cubit.fetchVehicles();
      final before = cubit.state;
      final emitted = <VehicleState>[];
      final subscription = cubit.stream.listen(emitted.add);

      final result = await cubit.updateVehicle(_vehicle(id: 1));

      expect(result, isA<OperationFailure>());
      expect(cubit.state, before);
      expect(emitted, isEmpty);
      await subscription.cancel();
      await cubit.close();
    });

    test(
      'refresh failure reports a follow-up failure and keeps old data',
      () async {
        final repository = _FakeVehicleRepository([_vehicle(id: 1)]);
        final cubit = VehicleCubit(repository);
        await cubit.fetchVehicles();
        repository.readError = StateError('refresh failed');

        final result = await cubit.addVehicle(_vehicle(id: 2));

        expect(result, isA<OperationSuccess>());
        expect(
          (result as OperationSuccess).followUpFailure,
          isA<OperationFailure>(),
        );
        expect(
          cubit.state,
          VehicleLoaded([
            _vehicle(id: 1),
          ], refreshError: 'Bad state: refresh failed'),
        );
        await cubit.close();
      },
    );
  });

  group('MaintenancePlanCubit write protocol', () {
    test('waits for refresh before returning success', () async {
      final repository = _FakeMaintenanceRepository(
        planItems: [_planItem(id: 1)],
      );
      final cubit = MaintenancePlanCubit(repository, 1);
      await cubit.fetchPlanItems();

      final result = await cubit.addPlanItem(_planItem(id: 2));

      expect(result, isA<OperationSuccess>());
      expect(repository.events, [
        'getPlanItems',
        'addPlanItem',
        'getPlanItems',
      ]);
      expect(
        cubit.state,
        MaintenancePlanLoaded([_planItem(id: 1), _planItem(id: 2)]),
      );
      await cubit.close();
    });

    test('write failure keeps the last successful data', () async {
      final repository = _FakeMaintenanceRepository(
        planItems: [_planItem(id: 1)],
      )..planWriteError = StateError('write failed');
      final cubit = MaintenancePlanCubit(repository, 1);
      await cubit.fetchPlanItems();
      final before = cubit.state;

      final result = await cubit.updatePlanItem(_planItem(id: 1));

      expect(result, isA<OperationFailure>());
      expect(cubit.state, before);
      await cubit.close();
    });

    test(
      'refresh failure reports a follow-up failure and keeps old data',
      () async {
        final repository = _FakeMaintenanceRepository(
          planItems: [_planItem(id: 1)],
        );
        final cubit = MaintenancePlanCubit(repository, 1);
        await cubit.fetchPlanItems();
        repository.planReadError = StateError('refresh failed');

        final result = await cubit.deletePlanItem(1);

        expect(result, isA<OperationSuccess>());
        expect(
          (result as OperationSuccess).followUpFailure,
          isA<OperationFailure>(),
        );
        expect(
          cubit.state,
          MaintenancePlanLoaded([
            _planItem(id: 1),
          ], refreshError: 'Bad state: refresh failed'),
        );
        await cubit.close();
      },
    );
  });

  group('ServiceLogCubit write protocol', () {
    test('waits for refresh before returning success', () async {
      final repository = _FakeMaintenanceRepository(
        serviceLogs: [_serviceLog(id: 1)],
      );
      final cubit = ServiceLogCubit(repository, 1);
      await cubit.fetchServiceLogs();

      final result = await cubit.addServiceLog(_serviceEntry(id: 2), const [
        PerformedItemInput(customItemName: 'Inspection'),
      ]);

      expect(result, isA<OperationSuccess>());
      expect(repository.events, [
        'getServiceLogs',
        'addServiceLog',
        'getServiceLogs',
      ]);
      expect(
        cubit.state,
        ServiceLogLoaded([_serviceLog(id: 1), _serviceLog(id: 2)]),
      );
      await cubit.close();
    });

    test('write failure keeps the last successful data', () async {
      final repository = _FakeMaintenanceRepository(
        serviceLogs: [_serviceLog(id: 1)],
      )..logWriteError = StateError('write failed');
      final cubit = ServiceLogCubit(repository, 1);
      await cubit.fetchServiceLogs();
      final before = cubit.state;

      final result = await cubit.updateServiceLog(_serviceEntry(id: 1), const [
        PerformedItemInput(customItemName: 'Inspection'),
      ]);

      expect(result, isA<OperationFailure>());
      expect(cubit.state, before);
      await cubit.close();
    });

    test(
      'refresh failure reports a follow-up failure and keeps old data',
      () async {
        final repository = _FakeMaintenanceRepository(
          serviceLogs: [_serviceLog(id: 1)],
        );
        final cubit = ServiceLogCubit(repository, 1);
        await cubit.fetchServiceLogs();
        repository.logReadError = StateError('refresh failed');

        final result = await cubit.deleteServiceLog(1);

        expect(result, isA<OperationSuccess>());
        expect(
          (result as OperationSuccess).followUpFailure,
          isA<OperationFailure>(),
        );
        expect(
          cubit.state,
          ServiceLogLoaded([
            _serviceLog(id: 1),
          ], refreshError: 'Bad state: refresh failed'),
        );
        await cubit.close();
      },
    );
  });

  group('initial loading and close safety', () {
    test('Plan and Log constructors do not fetch implicitly', () async {
      final repository = _FakeMaintenanceRepository();
      final planCubit = MaintenancePlanCubit(repository, 1);
      final logCubit = ServiceLogCubit(repository, 1);

      await Future<void>.delayed(Duration.zero);

      expect(repository.planReadCount, 0);
      expect(repository.logReadCount, 0);
      await planCubit.fetchPlanItems();
      await logCubit.fetchServiceLogs();
      expect(repository.planReadCount, 1);
      expect(repository.logReadCount, 1);
      await planCubit.close();
      await logCubit.close();
    });

    test('an in-flight load does not emit after the Cubit closes', () async {
      final completer = Completer<List<MaintenancePlanItem>>();
      final repository = _FakeMaintenanceRepository()
        ..blockedPlanRead = completer;
      final cubit = MaintenancePlanCubit(repository, 1);
      final emitted = <MaintenancePlanState>[];
      final subscription = cubit.stream.listen(emitted.add);

      final load = cubit.fetchPlanItems();
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      completer.complete([_planItem(id: 1)]);
      await load;

      expect(emitted, [MaintenancePlanLoading()]);
      await subscription.cancel();
    });
  });
}

Vehicle _vehicle({required int id}) {
  return Vehicle(
    id: id,
    name: 'Vehicle $id',
    mileage: 1000,
    mileageLastUpdated: DateTime(2026, 1, 1),
    boughtDate: DateTime(2025, 1, 1),
  );
}

MaintenancePlanItem _planItem({required int id}) {
  return MaintenancePlanItem(
    id: id,
    vehicleId: 1,
    itemName: 'Item $id',
    intervalTimeMonths: 12,
  );
}

ServiceLogEntry _serviceEntry({required int id}) {
  return ServiceLogEntry(
    id: id,
    vehicleId: 1,
    serviceDate: DateTime(2026, 1, id),
    mileageAtService: 1000 + id.toDouble(),
  );
}

ServiceLogWithItems _serviceLog({required int id}) {
  return ServiceLogWithItems(
    entry: _serviceEntry(id: id),
    performedItems: [
      ServiceLogPerformedItem(
        id: id,
        serviceLogId: id,
        customItemName: 'Inspection',
        displayName: 'Inspection',
      ),
    ],
  );
}

class _FakeVehicleRepository extends VehicleRepository {
  _FakeVehicleRepository(List<Vehicle> vehicles)
    : vehicles = List<Vehicle>.of(vehicles);

  final List<String> events = [];
  final List<Vehicle> vehicles;
  Object? readError;
  Object? writeError;

  @override
  Future<List<Vehicle>> getVehicles() async {
    events.add('getVehicles');
    if (readError case final error?) throw error;
    return List<Vehicle>.of(vehicles);
  }

  @override
  Future<void> addVehicle(Vehicle vehicle) async {
    events.add('addVehicle');
    if (writeError case final error?) throw error;
    vehicles.add(vehicle);
  }

  @override
  Future<void> updateVehicle(Vehicle vehicle) async {
    events.add('updateVehicle');
    if (writeError case final error?) throw error;
    final index = vehicles.indexWhere((current) => current.id == vehicle.id);
    if (index >= 0) vehicles[index] = vehicle;
  }
}

class _FakeMaintenanceRepository extends MaintenanceRepository {
  _FakeMaintenanceRepository({
    List<MaintenancePlanItem> planItems = const [],
    List<ServiceLogWithItems> serviceLogs = const [],
  }) : planItems = List<MaintenancePlanItem>.of(planItems),
       serviceLogs = List<ServiceLogWithItems>.of(serviceLogs);

  final List<String> events = [];
  final List<MaintenancePlanItem> planItems;
  final List<ServiceLogWithItems> serviceLogs;
  Object? planReadError;
  Object? planWriteError;
  Object? logReadError;
  Object? logWriteError;
  Completer<List<MaintenancePlanItem>>? blockedPlanRead;
  int planReadCount = 0;
  int logReadCount = 0;

  @override
  Future<List<MaintenancePlanItem>> getPlanItems(int vehicleId) async {
    events.add('getPlanItems');
    planReadCount++;
    if (blockedPlanRead case final blocker?) return blocker.future;
    if (planReadError case final error?) throw error;
    return List<MaintenancePlanItem>.of(planItems);
  }

  @override
  Future<void> addPlanItem(MaintenancePlanItem item) async {
    events.add('addPlanItem');
    if (planWriteError case final error?) throw error;
    planItems.add(item);
  }

  @override
  Future<void> updatePlanItem(MaintenancePlanItem item) async {
    events.add('updatePlanItem');
    if (planWriteError case final error?) throw error;
    final index = planItems.indexWhere((current) => current.id == item.id);
    if (index >= 0) planItems[index] = item;
  }

  @override
  Future<void> deletePlanItem(int itemId) async {
    events.add('deletePlanItem');
    if (planWriteError case final error?) throw error;
    planItems.removeWhere((item) => item.id == itemId);
  }

  @override
  Future<List<ServiceLogWithItems>> getServiceLogs(int vehicleId) async {
    events.add('getServiceLogs');
    logReadCount++;
    if (logReadError case final error?) throw error;
    return List<ServiceLogWithItems>.of(serviceLogs);
  }

  @override
  Future<ServiceLogWithItems?> addServiceLog(
    ServiceLogEntry logEntry,
    List<PerformedItemInput> performedItems,
  ) async {
    events.add('addServiceLog');
    if (logWriteError case final error?) throw error;
    final saved = _serviceLog(id: logEntry.id!);
    serviceLogs.add(saved);
    return saved;
  }

  @override
  Future<bool> updateServiceLog(
    ServiceLogEntry logEntry,
    List<PerformedItemInput> performedItems,
  ) async {
    events.add('updateServiceLog');
    if (logWriteError case final error?) throw error;
    final index = serviceLogs.indexWhere(
      (current) => current.entry.id == logEntry.id,
    );
    if (index < 0) return false;
    serviceLogs[index] = _serviceLog(id: logEntry.id!);
    return true;
  }

  @override
  Future<bool> deleteServiceLog(int logId) async {
    events.add('deleteServiceLog');
    if (logWriteError case final error?) throw error;
    final before = serviceLogs.length;
    serviceLogs.removeWhere((log) => log.entry.id == logId);
    return serviceLogs.length != before;
  }
}
