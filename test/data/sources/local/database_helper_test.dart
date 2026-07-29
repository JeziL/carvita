import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'package:carvita/application/ports/clock.dart';
import 'package:carvita/application/use_cases/load_upcoming_maintenance.dart';
import 'package:carvita/core/services/prediction_service.dart';
import 'package:carvita/data/sources/local/database_helper.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';

void main() {
  ffi.sqfliteFfiInit();
  sqflite.databaseFactory = ffi.databaseFactoryFfi;

  final databaseHelper = DatabaseHelper();
  late String databasePath;

  setUp(() async {
    await databaseHelper.close();
    databasePath = path.join(
      await sqflite.getDatabasesPath(),
      DatabaseHelper.dbName,
    );
    await sqflite.deleteDatabase(databasePath);
    await databaseHelper.database;
  });

  tearDown(() async {
    await databaseHelper.close();
    await sqflite.deleteDatabase(databasePath);
  });

  test('database access waits for an exclusive file operation', () async {
    final operationStarted = Completer<void>();
    final allowOperationToFinish = Completer<void>();
    var databaseAccessCompleted = false;

    final maintenance = databaseHelper.runExclusiveMaintenance((
      connection,
    ) async {
      await connection.close();
      operationStarted.complete();
      await allowOperationToFinish.future;
      await connection.open();
    });
    await operationStarted.future;

    final databaseAccess = databaseHelper.database.then((database) {
      databaseAccessCompleted = true;
      return database;
    });
    await Future<void>.delayed(Duration.zero);
    expect(databaseAccessCompleted, isFalse);

    allowOperationToFinish.complete();
    await maintenance;
    final database = await databaseAccess;

    expect(database.isOpen, isTrue);
    expect(databaseAccessCompleted, isTrue);
  });

  test(
    'vehicle summaries omit image BLOB and detail loads it on demand',
    () async {
      final image = Uint8List.fromList(
        List<int>.generate(4096, (i) => i % 256),
      );
      final vehicleId = await databaseHelper.insertVehicle(
        Vehicle(
          name: 'Summary',
          mileage: 100,
          mileageLastUpdated: DateTime(2026, 7, 1),
          boughtDate: DateTime(2025, 1, 1),
          image: image,
        ),
      );

      databaseHelper.resetDiagnosticReadQueryCount();
      final summaries = await databaseHelper.getAllVehicles();
      expect(databaseHelper.diagnosticReadQueryCount, 1);
      expect(summaries.single.imageLoaded, isFalse);
      expect(summaries.single.image, isNull);

      final loadedImage = await databaseHelper.getVehicleImage(vehicleId);
      expect(loadedImage, image);
      final detail = await databaseHelper.getVehicleById(vehicleId);
      expect(detail?.imageLoaded, isTrue);
      expect(detail?.image, image);

      await databaseHelper.updateVehicle(
        summaries.single.copyWith(name: 'Updated summary'),
      );
      final updatedDetail = await databaseHelper.getVehicleById(vehicleId);
      expect(updatedDetail?.name, 'Updated summary');
      expect(updatedDetail?.image, image);
    },
  );

  test('service logs and performed items use one read query', () async {
    final vehicleId = await _insertVehicle(databaseHelper);
    final planId = await databaseHelper.insertMaintenancePlanItem(
      MaintenancePlanItem(
        vehicleId: vehicleId,
        itemName: 'Oil',
        intervalTimeMonths: 12,
      ),
      baselineDate: DateTime(2026, 7, 28),
    );
    for (var index = 0; index < 250; index++) {
      await databaseHelper.insertServiceLog(
        ServiceLogEntry(
          vehicleId: vehicleId,
          serviceDate: DateTime(2026, 1, 1).add(Duration(days: index)),
          mileageAtService: 1000 + index.toDouble(),
        ),
        [
          PerformedItemInput(maintenancePlanItemId: planId),
          PerformedItemInput(customItemName: 'Custom $index'),
        ],
      );
    }

    databaseHelper.resetDiagnosticReadQueryCount();
    final stopwatch = Stopwatch()..start();
    final logs = await databaseHelper.getServiceLogsWithItemsForVehicle(
      vehicleId,
    );
    stopwatch.stop();

    expect(logs, hasLength(250));
    expect(logs.every((log) => log.performedItems.length == 2), isTrue);
    expect(databaseHelper.diagnosticReadQueryCount, 1);
    debugPrint(
      '250 service logs: ${stopwatch.elapsedMicroseconds} µs, '
      '${databaseHelper.diagnosticReadQueryCount} read query',
    );
  });

  test('prediction snapshot query count is constant as data grows', () async {
    for (var vehicleIndex = 0; vehicleIndex < 200; vehicleIndex++) {
      final vehicleId = await _insertVehicle(
        databaseHelper,
        name: 'Vehicle $vehicleIndex',
      );
      final planId = await databaseHelper.insertMaintenancePlanItem(
        MaintenancePlanItem(
          vehicleId: vehicleId,
          itemName: 'Oil $vehicleIndex',
          intervalMileage: 10000,
        ),
        baselineDate: DateTime(2026, 7, 28),
      );
      await databaseHelper.insertServiceLog(
        ServiceLogEntry(
          vehicleId: vehicleId,
          serviceDate: DateTime(2026, 1, 1),
          mileageAtService: 1000,
        ),
        [PerformedItemInput(maintenancePlanItemId: planId)],
      );
    }

    databaseHelper.resetDiagnosticReadQueryCount();
    final stopwatch = Stopwatch()..start();
    final snapshot = await MaintenanceRepository(
      dbHelper: databaseHelper,
    ).getPredictionSnapshot();
    stopwatch.stop();

    expect(snapshot.planItemsByVehicleId, hasLength(200));
    expect(snapshot.serviceLogsByVehicleId, hasLength(200));
    expect(snapshot.performedItemLinksByVehicleId, hasLength(200));
    expect(databaseHelper.diagnosticReadQueryCount, 4);
    databaseHelper.resetDiagnosticReadQueryCount();
    const clock = _FixedClock();
    await LoadUpcomingMaintenance(
      MaintenanceRepository(dbHelper: databaseHelper),
      PredictionService(clock),
      clock,
    )();
    expect(databaseHelper.diagnosticReadQueryCount, 4);
    debugPrint(
      '200-vehicle prediction snapshot: ${stopwatch.elapsedMicroseconds} µs, '
      '4 snapshot queries / 4 full prediction queries',
    );
  });
}

final class _FixedClock implements Clock {
  const _FixedClock();

  @override
  DateTime now() => DateTime(2026, 7, 28);
}

Future<int> _insertVehicle(
  DatabaseHelper databaseHelper, {
  String name = 'Vehicle',
}) {
  return databaseHelper.insertVehicle(
    Vehicle(
      name: name,
      mileage: 1000,
      mileageLastUpdated: DateTime(2026, 1, 1),
      boughtDate: DateTime(2025, 1, 1),
    ),
  );
}
