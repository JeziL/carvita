import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'package:carvita/application/ports/clock.dart';
import 'package:carvita/core/services/prediction_service.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/service_log_performed_item_link.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/sources/local/database_helper.dart';
import 'package:carvita/data/sources/local/database_schema.dart';

void main() {
  ffi.sqfliteFfiInit();
  sqflite.databaseFactory = ffi.databaseFactoryFfi;

  late DatabaseHelper helper;
  late Directory testDirectory;
  late String databasePath;

  setUp(() async {
    testDirectory = await Directory.systemTemp.createTemp(
      'carvita_database_migration_test_',
    );
    databasePath = path.join(testDirectory.path, DatabaseHelper.dbName);
    helper = DatabaseHelper.forTesting(databasePath: databasePath);
  });

  tearDown(() async {
    await helper.close();
    await sqflite.deleteDatabase(databasePath);
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  test(
    'fresh install creates schema v2 with foreign keys and indexes',
    () async {
      final database = await helper.database;

      expect(await _userVersion(database), DatabaseSchema.currentVersion);
      expect(await _foreignKeysEnabled(database), isTrue);
      expect(
        await _columnNames(database, 'maintenance_plan_items'),
        containsAll({'baselineDate', 'baselineMileage'}),
      );
      expect(
        await _indexNames(database),
        containsAll(DatabaseSchema.indexNames),
      );
      expect((await helper.getConsistencyReport()).isClean, isTrue);
    },
  );

  test(
    'provided v1 fixture migrates without changing its predictions',
    () async {
      final fixture = File(
        path.join(
          Directory.current.path,
          'test',
          'fixtures',
          'database',
          'carvita_v1.db',
        ),
      );
      expect(await fixture.exists(), isTrue);
      await fixture.copy(databasePath);

      final legacyDatabase = await ffi.databaseFactoryFfi.openDatabase(
        databasePath,
        options: sqflite.OpenDatabaseOptions(
          readOnly: true,
          singleInstance: false,
        ),
      );
      final before = await _predictionSignatures(legacyDatabase);
      final beforeCounts = await _tableCounts(legacyDatabase);
      await legacyDatabase.close();

      final migratedDatabase = await helper.database;
      final after = await _predictionSignatures(migratedDatabase);

      expect(beforeCounts, {
        'vehicles': 1,
        'maintenance_plan_items': 9,
        'service_log_entries': 12,
        'service_log_performed_items': 38,
      });
      expect(after, before);
      expect(await _tableCounts(migratedDatabase), beforeCounts);
      expect(await _userVersion(migratedDatabase), 2);
      expect(await _foreignKeysEnabled(migratedDatabase), isTrue);
      expect(
        await _indexNames(migratedDatabase),
        containsAll(DatabaseSchema.indexNames),
      );
      expect((await helper.getConsistencyReport()).isClean, isTrue);

      final baselineRows = await migratedDatabase.rawQuery('''
        SELECT plan.baselineDate, plan.baselineMileage, vehicle.bought_date
        FROM maintenance_plan_items plan
        JOIN vehicles vehicle ON vehicle.id = plan.vehicleId
      ''');
      expect(baselineRows, hasLength(9));
      for (final row in baselineRows) {
        expect(row['baselineDate'], row['bought_date']);
        expect((row['baselineMileage'] as num).toDouble(), 0);
      }
    },
  );

  test(
    'v1 migration repairs relational anomalies without losing names',
    () async {
      final v1 = await _createV1Database(databasePath);
      await v1.insert('vehicles', _vehicleValues(id: 1, name: 'One'));
      await v1.insert('vehicles', _vehicleValues(id: 2, name: 'Two'));
      await v1.insert(
        'maintenance_plan_items',
        _planValues(id: 1, vehicleId: 1, name: 'Valid'),
      );
      await v1.insert(
        'maintenance_plan_items',
        _planValues(id: 2, vehicleId: 99, name: 'Orphan plan'),
      );
      await v1.insert(
        'maintenance_plan_items',
        _planValues(id: 3, vehicleId: 2, name: 'Other vehicle plan'),
      );
      await v1.insert('service_log_entries', _logValues(id: 1, vehicleId: 1));
      await v1.insert('service_log_entries', _logValues(id: 2, vehicleId: 99));

      await v1.insert('service_log_performed_items', {
        'id': 1,
        'serviceLogId': 1,
        'maintenancePlanItemId': 1,
      });
      await v1.insert('service_log_performed_items', {
        'id': 2,
        'serviceLogId': 1,
        'maintenancePlanItemId': 3,
      });
      await v1.insert('service_log_performed_items', {
        'id': 3,
        'serviceLogId': 1,
        'maintenancePlanItemId': 1,
        'customItemName': 'Manual item',
      });
      await v1.insert('service_log_performed_items', {
        'id': 4,
        'serviceLogId': 1,
        'maintenancePlanItemId': 999,
      });
      await v1.insert('service_log_performed_items', {
        'id': 5,
        'serviceLogId': 999,
        'maintenancePlanItemId': 1,
      });
      await v1.insert('service_log_performed_items', {
        'id': 6,
        'serviceLogId': 1,
        'maintenancePlanItemId': 2,
      });
      await v1.insert('service_log_performed_items', {
        'id': 7,
        'serviceLogId': 1,
      });
      await v1.insert('service_log_performed_items', {
        'id': 8,
        'serviceLogId': 2,
        'customItemName': 'Invisible orphan log item',
      });
      await v1.close();

      final migrated = await helper.database;

      expect((await helper.getConsistencyReport()).isClean, isTrue);
      expect(
        await migrated.query('maintenance_plan_items', orderBy: 'id'),
        hasLength(2),
      );
      expect(
        await migrated.query('service_log_entries', orderBy: 'id'),
        hasLength(1),
      );
      final performed = await migrated.query(
        'service_log_performed_items',
        orderBy: 'id',
      );
      expect(performed, hasLength(4));
      expect(performed[0]['maintenancePlanItemId'], 1);
      expect(performed[1]['maintenancePlanItemId'], isNull);
      expect(performed[1]['customItemName'], 'Other vehicle plan');
      expect(performed[2]['maintenancePlanItemId'], isNull);
      expect(performed[2]['customItemName'], 'Manual item');
      expect(performed[3]['maintenancePlanItemId'], isNull);
      expect(performed[3]['customItemName'], 'Orphan plan');
      expect(await migrated.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test('invalid v1 values abort migration and retain schema v1', () async {
    final v1 = await _createV1Database(databasePath);
    final invalidVehicle = _vehicleValues(id: 1, name: 'Invalid')
      ..['bought_date'] = 'not-a-date';
    await v1.insert('vehicles', invalidVehicle);
    await v1.close();

    await expectLater(
      helper.database,
      throwsA(isA<DatabaseMigrationException>()),
    );

    final recovered = await ffi.databaseFactoryFfi.openDatabase(
      databasePath,
      options: sqflite.OpenDatabaseOptions(
        readOnly: true,
        singleInstance: false,
      ),
    );
    expect(await _userVersion(recovered), 1);
    expect(
      await _columnNames(recovered, 'maintenance_plan_items'),
      isNot(contains('baselineDate')),
    );
    expect(await recovered.query('vehicles'), hasLength(1));
    await recovered.close();
  });

  test('an error after migration rolls all schema changes back', () async {
    final directPath = path.join(
      path.dirname(databasePath),
      'migration_rollback.db',
    );
    await sqflite.deleteDatabase(directPath);
    final v1 = await _createV1Database(directPath);
    await v1.insert('vehicles', _vehicleValues(id: 1, name: 'Rollback'));
    await v1.insert(
      'maintenance_plan_items',
      _planValues(id: 1, vehicleId: 1, name: 'Oil'),
    );
    await v1.close();

    await expectLater(
      ffi.databaseFactoryFfi.openDatabase(
        directPath,
        options: sqflite.OpenDatabaseOptions(
          version: 2,
          singleInstance: false,
          onConfigure: DatabaseSchema.configure,
          onUpgrade: (database, oldVersion, newVersion) async {
            await DatabaseSchema.upgrade(database, oldVersion, newVersion);
            throw StateError('Injected failure after migration');
          },
        ),
      ),
      throwsA(isA<StateError>()),
    );

    final recovered = await ffi.databaseFactoryFfi.openDatabase(
      directPath,
      options: sqflite.OpenDatabaseOptions(
        readOnly: true,
        singleInstance: false,
      ),
    );
    expect(await _userVersion(recovered), 1);
    expect(
      await _columnNames(recovered, 'maintenance_plan_items'),
      isNot(contains('baselineDate')),
    );
    expect(await _indexNames(recovered), isEmpty);
    expect(await recovered.query('maintenance_plan_items'), hasLength(1));
    await recovered.close();
    await sqflite.deleteDatabase(directPath);
  });

  test(
    'migration is idempotent and never moves an existing baseline',
    () async {
      final database = await helper.database;
      await database.insert('vehicles', _vehicleValues(id: 1, name: 'One'));
      await database.insert('maintenance_plan_items', {
        ..._planValues(id: 1, vehicleId: 1, name: 'Oil'),
        'baselineDate': '2026-06-01T00:00:00.000',
        'baselineMileage': 12345.0,
      });

      await DatabaseSchema.upgrade(database, 1, 2);
      await DatabaseSchema.upgrade(database, 1, 2);

      final plan = (await database.query('maintenance_plan_items')).single;
      expect(plan['baselineDate'], '2026-06-01T00:00:00.000');
      expect(plan['baselineMileage'], 12345.0);
      expect(
        await _indexNames(database),
        containsAll(DatabaseSchema.indexNames),
      );
      expect((await DatabaseSchema.audit(database)).isClean, isTrue);
    },
  );

  test(
    'plan creation captures baseline atomically and edits preserve it',
    () async {
      final vehicleId = await helper.insertVehicle(
        Vehicle(
          name: 'Vehicle',
          mileage: 45678,
          mileageLastUpdated: DateTime(2026, 7, 1),
          boughtDate: DateTime(2020, 1, 1),
        ),
      );
      final planId = await helper.insertMaintenancePlanItem(
        MaintenancePlanItem(
          vehicleId: vehicleId,
          itemName: 'Oil',
          intervalMileage: 10000,
        ),
        baselineDate: DateTime(2026, 7, 29),
      );

      await helper.updateVehicle(
        (await helper.getVehicleById(vehicleId))!.copyWith(mileage: 50000),
      );
      final original = (await helper.getMaintenancePlanItemsForVehicle(
        vehicleId,
      )).single;
      expect(original.baselineDate, DateTime(2026, 7, 29));
      expect(original.baselineMileage, 45678);

      await helper.updateMaintenancePlanItem(
        MaintenancePlanItem(
          id: planId,
          vehicleId: vehicleId,
          itemName: 'Updated oil',
          intervalMileage: 12000,
        ),
      );
      final edited = (await helper.getMaintenancePlanItemsForVehicle(
        vehicleId,
      )).single;
      expect(edited.baselineDate, DateTime(2026, 7, 29));
      expect(edited.baselineMileage, 45678);
    },
  );

  test(
    'foreign keys cascade deletes while soft delete retains history',
    () async {
      final vehicleId = await helper.insertVehicle(
        Vehicle(
          name: 'Vehicle',
          mileage: 1000,
          mileageLastUpdated: DateTime(2026, 1, 1),
          boughtDate: DateTime(2025, 1, 1),
        ),
      );
      final planId = await helper.insertMaintenancePlanItem(
        MaintenancePlanItem(
          vehicleId: vehicleId,
          itemName: 'Oil',
          intervalTimeMonths: 12,
        ),
        baselineDate: DateTime(2026, 1, 1),
      );
      final insertedLog = await helper.insertServiceLog(
        ServiceLogEntry(
          vehicleId: vehicleId,
          serviceDate: DateTime(2026, 6, 1),
          mileageAtService: 5000,
        ),
        [PerformedItemInput(maintenancePlanItemId: planId)],
      );

      await helper.softDeleteMaintenancePlanItem(planId);
      final logId = insertedLog!.entry.id!;
      final softDeletedHistory = (await helper.getServiceLogByIdWithItems(
        logId,
      ))!.performedItems.single;
      expect(softDeletedHistory.maintenancePlanItemId, planId);
      expect(softDeletedHistory.customItemName, isNull);
      expect(softDeletedHistory.displayName, 'Oil');

      await helper.deleteMaintenancePlanItem(planId);
      final preservedHistory = (await helper.getServiceLogByIdWithItems(
        logId,
      ))!.performedItems.single;
      expect(preservedHistory.maintenancePlanItemId, isNull);
      expect(preservedHistory.customItemName, 'Oil');

      await helper.deleteVehicle(vehicleId);
      final database = await helper.database;
      expect(await database.query('maintenance_plan_items'), isEmpty);
      expect(await database.query('service_log_entries'), isEmpty);
      expect(await database.query('service_log_performed_items'), isEmpty);
      expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test('hot queries use the four minimal v2 indexes', () async {
    final database = await helper.database;
    final plans = await _queryPlan(
      database,
      'SELECT * FROM maintenance_plan_items '
      'WHERE vehicleId = ? AND isActive = ? ORDER BY id',
      [1, 1],
    );
    final logs = await _queryPlan(
      database,
      'SELECT * FROM service_log_entries '
      'WHERE vehicleId = ? ORDER BY serviceDate DESC, id DESC',
      [1],
    );
    final performedByLog = await _queryPlan(
      database,
      'SELECT * FROM service_log_performed_items '
      'WHERE serviceLogId = ? ORDER BY id',
      [1],
    );
    final performedByPlan = await _queryPlan(
      database,
      'SELECT serviceLogId FROM service_log_performed_items '
      'WHERE maintenancePlanItemId = ?',
      [1],
    );

    expect(plans, contains(DatabaseSchema.planLookupIndex));
    expect(logs, contains(DatabaseSchema.serviceLogLookupIndex));
    expect(performedByLog, contains(DatabaseSchema.performedItemLogIndex));
    expect(performedByPlan, contains(DatabaseSchema.performedItemPlanIndex));
    debugPrint(
      'v2 query plans: $plans | $logs | $performedByLog | $performedByPlan',
    );
  });

  test('representative indexed writes remain consistent', () async {
    final database = await helper.database;
    final stopwatch = Stopwatch()..start();
    await database.transaction((transaction) async {
      for (var index = 0; index < 500; index++) {
        final vehicleId = await transaction.insert(
          'vehicles',
          _vehicleValues(name: 'Vehicle $index'),
        );
        final planId = await transaction.insert('maintenance_plan_items', {
          ..._planValues(vehicleId: vehicleId, name: 'Plan $index'),
          'baselineDate': '2026-07-29T00:00:00.000',
          'baselineMileage': index.toDouble(),
        });
        final logId = await transaction.insert(
          'service_log_entries',
          _logValues(vehicleId: vehicleId),
        );
        await transaction.insert('service_log_performed_items', {
          'serviceLogId': logId,
          'maintenancePlanItemId': planId,
        });
      }
    });
    stopwatch.stop();

    expect((await _tableCounts(database))['vehicles'], 500);
    expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    debugPrint(
      'v2 indexed write benchmark: 500 vehicle/plan/log/link groups in '
      '${stopwatch.elapsedMicroseconds} µs',
    );
  });
}

Future<sqflite.Database> _createV1Database(String databasePath) {
  return ffi.databaseFactoryFfi.openDatabase(
    databasePath,
    options: sqflite.OpenDatabaseOptions(
      version: 1,
      singleInstance: false,
      onCreate: _createV1Schema,
    ),
  );
}

Future<void> _createV1Schema(sqflite.Database database, int version) async {
  await database.execute('''
    CREATE TABLE vehicles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      mileage REAL NOT NULL,
      mileage_last_updated TEXT NOT NULL,
      bought_date TEXT NOT NULL,
      image BLOB,
      model TEXT,
      plate_number TEXT,
      vin TEXT,
      engine_number TEXT
    )
  ''');
  await database.execute('''
    CREATE TABLE maintenance_plan_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      vehicleId INTEGER NOT NULL,
      itemName TEXT NOT NULL,
      intervalTimeMonths INTEGER,
      intervalMileage INTEGER,
      firstIntervalTimeMonths INTEGER,
      firstIntervalMileage INTEGER,
      notes TEXT,
      isActive INTEGER DEFAULT 1 NOT NULL,
      FOREIGN KEY (vehicleId) REFERENCES vehicles (id) ON DELETE CASCADE
    )
  ''');
  await database.execute('''
    CREATE TABLE service_log_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      vehicleId INTEGER NOT NULL,
      serviceDate TEXT NOT NULL,
      mileageAtService REAL NOT NULL,
      cost REAL,
      notes TEXT,
      FOREIGN KEY (vehicleId) REFERENCES vehicles (id) ON DELETE CASCADE
    )
  ''');
  await database.execute('''
    CREATE TABLE service_log_performed_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      serviceLogId INTEGER NOT NULL,
      maintenancePlanItemId INTEGER,
      customItemName TEXT,
      FOREIGN KEY (serviceLogId) REFERENCES service_log_entries (id)
        ON DELETE CASCADE,
      FOREIGN KEY (maintenancePlanItemId)
        REFERENCES maintenance_plan_items (id) ON DELETE SET NULL
    )
  ''');
}

Map<String, Object?> _vehicleValues({int? id, required String name}) {
  return {
    if (id != null) 'id': id,
    'name': name,
    'mileage': 1000.0,
    'mileage_last_updated': '2026-07-01T00:00:00.000',
    'bought_date': '2020-01-01T00:00:00.000',
  };
}

Map<String, Object?> _planValues({
  int? id,
  required int vehicleId,
  required String name,
}) {
  return {
    if (id != null) 'id': id,
    'vehicleId': vehicleId,
    'itemName': name,
    'intervalTimeMonths': 12,
    'isActive': 1,
  };
}

Map<String, Object?> _logValues({int? id, required int vehicleId}) {
  return {
    if (id != null) 'id': id,
    'vehicleId': vehicleId,
    'serviceDate': '2026-06-01T00:00:00.000',
    'mileageAtService': 5000.0,
  };
}

Future<int> _userVersion(sqflite.Database database) async {
  final rows = await database.rawQuery('PRAGMA user_version');
  return (rows.single.values.single as num).toInt();
}

Future<bool> _foreignKeysEnabled(sqflite.Database database) async {
  final rows = await database.rawQuery('PRAGMA foreign_keys');
  return rows.single.values.single == 1;
}

Future<Set<String>> _columnNames(
  sqflite.Database database,
  String table,
) async {
  final rows = await database.rawQuery('PRAGMA table_info("$table")');
  return rows.map((row) => row['name']).whereType<String>().toSet();
}

Future<Set<String>> _indexNames(sqflite.Database database) async {
  final rows = await database.rawQuery('''
    SELECT name
    FROM sqlite_master
    WHERE type = 'index' AND sql IS NOT NULL
  ''');
  return rows.map((row) => row['name']).whereType<String>().toSet();
}

Future<Map<String, int>> _tableCounts(sqflite.Database database) async {
  const tables = [
    'vehicles',
    'maintenance_plan_items',
    'service_log_entries',
    'service_log_performed_items',
  ];
  return {
    for (final table in tables)
      table:
          sqflite.Sqflite.firstIntValue(
            await database.rawQuery('SELECT COUNT(*) FROM $table'),
          ) ??
          0,
  };
}

Future<List<String>> _predictionSignatures(sqflite.Database database) async {
  final vehicles = (await database.query(
    'vehicles',
  )).map(Vehicle.fromMap).toList(growable: false);
  final plans = (await database.query(
    'maintenance_plan_items',
  )).map(MaintenancePlanItem.fromMap).toList(growable: false);
  final logs = (await database.query(
    'service_log_entries',
  )).map(ServiceLogEntry.fromMap).toList(growable: false);
  final links =
      (await database.query(
            'service_log_performed_items',
            columns: const ['serviceLogId', 'maintenancePlanItemId'],
            where: 'maintenancePlanItemId IS NOT NULL',
          ))
          .map((row) {
            return ServiceLogPerformedItemLink(
              serviceLogId: row['serviceLogId']! as int,
              maintenancePlanItemId: row['maintenancePlanItemId']! as int,
            );
          })
          .toList(growable: false);
  final service = PredictionService(_FixedClock(DateTime(2026, 7, 29)));

  final signatures = <String>[];
  for (final vehicle in vehicles) {
    final vehiclePlans = plans.where((plan) => plan.vehicleId == vehicle.id);
    final vehicleLogs = logs
        .where((log) => log.vehicleId == vehicle.id)
        .toList();
    final logIds = vehicleLogs.map((log) => log.id).whereType<int>().toSet();
    final vehicleLinks = links
        .where((link) => logIds.contains(link.serviceLogId))
        .toList();
    for (final plan in vehiclePlans) {
      final prediction = service.calculateNextServiceForItem(
        vehicle: vehicle,
        planItem: plan,
        allLogsForVehicle: vehicleLogs,
        allPerformedItemsForVehicle: vehicleLinks,
        currentDateOverride: DateTime(2026, 7, 29),
      );
      signatures.add(
        '${plan.id}|${prediction?.predictedDueDate.toIso8601String()}|'
        '${prediction?.predictedAtMileage}|${prediction?.basis.name}|'
        '${prediction?.isFirstOccurrence}',
      );
    }
  }
  signatures.sort();
  return signatures;
}

Future<String> _queryPlan(
  sqflite.Database database,
  String query,
  List<Object?> arguments,
) async {
  final rows = await database.rawQuery('EXPLAIN QUERY PLAN $query', arguments);
  return rows.map((row) => row['detail']).join(' | ');
}

final class _FixedClock implements Clock {
  const _FixedClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}
