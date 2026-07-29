import 'dart:async';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/service_log_performed_item_link.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/sources/local/database_schema.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal({String? databasePath})
    : _databasePathOverride = databasePath;

  /// Creates an isolated helper for database integration tests.
  DatabaseHelper.forTesting({required String databasePath})
    : _databasePathOverride = databasePath;

  final String? _databasePathOverride;
  Database? _database;
  Future<Database>? _openingDatabase;
  Completer<void>? _exclusiveOperation;
  static const String dbName = 'carvita_v1.db';
  static const int schemaVersion = DatabaseSchema.currentVersion;
  int _diagnosticReadQueryCount = 0;

  int get diagnosticReadQueryCount => _diagnosticReadQueryCount;

  void resetDiagnosticReadQueryCount() {
    _diagnosticReadQueryCount = 0;
  }

  Future<Database> get database async {
    while (true) {
      final exclusiveOperation = _exclusiveOperation;
      if (exclusiveOperation != null) {
        await exclusiveOperation.future;
        continue;
      }

      final currentDatabase = _database;
      if (currentDatabase != null && currentDatabase.isOpen) {
        return currentDatabase;
      }

      final openedDatabase = await _openDatabase();
      final operationAfterOpen = _exclusiveOperation;
      if (operationAfterOpen != null) {
        await operationAfterOpen.future;
        continue;
      }
      if (openedDatabase.isOpen && identical(_database, openedDatabase)) {
        return openedDatabase;
      }
    }
  }

  Future<Database> _initDB() async {
    final path =
        _databasePathOverride ?? join(await getDatabasesPath(), dbName);
    return await openDatabase(
      path,
      version: schemaVersion,
      onConfigure: DatabaseSchema.configure,
      onCreate: _onCreate,
      onUpgrade: DatabaseSchema.upgrade,
    );
  }

  Future<Database> _openDatabase() async {
    final currentDatabase = _database;
    if (currentDatabase != null && currentDatabase.isOpen) {
      return currentDatabase;
    }

    final openingDatabase = _openingDatabase ??= _initDB();
    try {
      final database = await openingDatabase;
      _database = database;
      return database;
    } finally {
      if (identical(_openingDatabase, openingDatabase)) {
        _openingDatabase = null;
      }
    }
  }

  /// Runs a database-file maintenance operation while preventing new callers
  /// from opening or obtaining this helper's shared connection.
  ///
  /// The provided connection deliberately bypasses the gate so the maintenance
  /// operation can close and reopen the database before releasing other callers.
  Future<T> runExclusiveMaintenance<T>(
    Future<T> Function(DatabaseMaintenanceConnection connection) operation,
  ) async {
    late Completer<void> operationCompleter;

    while (true) {
      final activeOperation = _exclusiveOperation;
      if (activeOperation != null) {
        await activeOperation.future;
        continue;
      }

      operationCompleter = Completer<void>();
      _exclusiveOperation = operationCompleter;
      break;
    }

    try {
      final openingDatabase = _openingDatabase;
      if (openingDatabase != null) {
        await openingDatabase;
      }
      return await operation(DatabaseMaintenanceConnection._(this));
    } finally {
      if (identical(_exclusiveOperation, operationCompleter)) {
        _exclusiveOperation = null;
        operationCompleter.complete();
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await DatabaseSchema.create(db, version);
  }

  // --- vehicle CRUD ---

  Future<int> insertVehicle(Vehicle vehicle) async {
    final db = await database;
    Map<String, dynamic> vehicleMap = vehicle.toMap();
    vehicleMap.remove('id'); // make SQLite auto-increment
    return await db.insert(
      'vehicles',
      vehicleMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Vehicle>> getAllVehicles() async {
    final db = await database;
    _diagnosticReadQueryCount++;
    final List<Map<String, dynamic>> maps = await db.query(
      'vehicles',
      columns: const [
        'id',
        'name',
        'mileage',
        'mileage_last_updated',
        'bought_date',
        'model',
        'plate_number',
        'vin',
        'engine_number',
      ],
      orderBy: 'id DESC',
    );
    if (maps.isEmpty) {
      return [];
    }
    return List.generate(maps.length, (i) => Vehicle.fromMap(maps[i]));
  }

  Future<Vehicle?> getVehicleById(int id) async {
    final db = await database;
    _diagnosticReadQueryCount++;
    final List<Map<String, dynamic>> maps = await db.query(
      'vehicles',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Vehicle.fromMap(maps.first);
    }
    return null;
  }

  Future<Uint8List?> getVehicleImage(int id) async {
    final db = await database;
    _diagnosticReadQueryCount++;
    final maps = await db.query(
      'vehicles',
      columns: const ['image'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first['image'] as Uint8List?;
  }

  Future<int> updateVehicle(Vehicle vehicle) async {
    final db = await database;
    final values = vehicle.toMap();
    if (!vehicle.imageLoaded) {
      values.remove('image');
    }
    return await db.update(
      'vehicles',
      values,
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
  }

  Future<int> deleteVehicle(int id) async {
    final db = await database;
    return await db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
  }

  // --- Maintenance plan CRUD ---

  Future<int> insertMaintenancePlanItem(
    MaintenancePlanItem item, {
    required DateTime baselineDate,
  }) async {
    final db = await database;
    return db.transaction((transaction) async {
      final vehicleRows = await transaction.query(
        'vehicles',
        columns: const ['mileage'],
        where: 'id = ?',
        whereArgs: [item.vehicleId],
        limit: 1,
      );
      if (vehicleRows.isEmpty) {
        throw StateError(
          'Cannot create a maintenance plan for a missing vehicle.',
        );
      }
      final capturedMileage = vehicleRows.single['mileage'];
      if (capturedMileage is! num) {
        throw StateError('The vehicle mileage is not numeric.');
      }

      final itemMap =
          item
              .copyWith(
                baselineDate: baselineDate,
                baselineMileage: capturedMileage.toDouble(),
              )
              .toMap()
            ..remove('id');
      return transaction.insert(
        'maintenance_plan_items',
        itemMap,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
  }

  Future<List<MaintenancePlanItem>> getMaintenancePlanItemsForVehicle(
    int vehicleId,
  ) async {
    final db = await database;
    _diagnosticReadQueryCount++;
    final List<Map<String, dynamic>> maps = await db.query(
      'maintenance_plan_items',
      where: 'vehicleId = ? AND isActive = ?',
      whereArgs: [vehicleId, 1],
      orderBy: 'id ASC',
    );
    if (maps.isEmpty) {
      return [];
    }
    return List.generate(
      maps.length,
      (i) => MaintenancePlanItem.fromMap(maps[i]),
    );
  }

  Future<int> updateMaintenancePlanItem(MaintenancePlanItem item) async {
    final db = await database;
    final values = item.toMap()
      ..remove('id')
      ..remove('vehicleId')
      ..remove('baselineDate')
      ..remove('baselineMileage');
    return await db.update(
      'maintenance_plan_items',
      values,
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> softDeleteMaintenancePlanItem(int itemId) async {
    final db = await database;
    return await db.update(
      'maintenance_plan_items',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<int> deleteMaintenancePlanItem(int itemId) async {
    final db = await database;
    return db.transaction((transaction) async {
      await transaction.rawUpdate(
        '''
        UPDATE service_log_performed_items
        SET customItemName = COALESCE(
              NULLIF(TRIM(customItemName), ''),
              (
                SELECT itemName
                FROM maintenance_plan_items
                WHERE id = ?
              )
            ),
            maintenancePlanItemId = NULL
        WHERE maintenancePlanItemId = ?
      ''',
        [itemId, itemId],
      );
      return transaction.delete(
        'maintenance_plan_items',
        where: 'id = ?',
        whereArgs: [itemId],
      );
    });
  }

  Future<DatabaseConsistencyReport> getConsistencyReport() async {
    final db = await database;
    return DatabaseSchema.audit(db);
  }

  // --- Maintenance log CRUD ---

  Future<ServiceLogWithItems?> insertServiceLog(
    ServiceLogEntry logEntry,
    List<PerformedItemInput> performedItems,
  ) async {
    final db = await database;
    int logId = -1;

    await db.transaction((txn) async {
      // Insert the main log entry
      Map<String, dynamic> logMap = logEntry.toMap();
      logMap.remove('id'); // Let SQLite autoincrement
      logId = await txn.insert('service_log_entries', logMap);

      // Insert performed items
      for (var itemInput in performedItems) {
        await txn.insert('service_log_performed_items', {
          'serviceLogId': logId,
          'maintenancePlanItemId': itemInput.maintenancePlanItemId,
          'customItemName': itemInput.customItemName,
        });
      }
    });
    if (logId != -1) {
      return getServiceLogByIdWithItems(
        logId,
      ); // Fetch the newly created log with items
    }
    return null;
  }

  Future<List<ServiceLogWithItems>> getServiceLogsWithItemsForVehicle(
    int vehicleId,
  ) async {
    final db = await database;
    _diagnosticReadQueryCount++;
    final rows = await db.rawQuery(
      '''
      SELECT
        sle.id,
        sle.vehicleId,
        sle.serviceDate,
        sle.mileageAtService,
        sle.cost,
        sle.notes,
        slpi.id AS performedItemId,
        slpi.serviceLogId,
        slpi.maintenancePlanItemId,
        slpi.customItemName,
        mpi.itemName AS predefinedItemName
      FROM service_log_entries sle
      LEFT JOIN service_log_performed_items slpi
        ON slpi.serviceLogId = sle.id
      LEFT JOIN maintenance_plan_items mpi
        ON slpi.maintenancePlanItemId = mpi.id
      WHERE sle.vehicleId = ?
      ORDER BY sle.serviceDate DESC, sle.id DESC, slpi.id ASC
      ''',
      [vehicleId],
    );
    return _mapJoinedServiceLogs(rows);
  }

  Future<ServiceLogWithItems?> getServiceLogByIdWithItems(int logId) async {
    final db = await database;
    _diagnosticReadQueryCount++;
    final rows = await db.rawQuery(
      '''
      SELECT
        sle.id,
        sle.vehicleId,
        sle.serviceDate,
        sle.mileageAtService,
        sle.cost,
        sle.notes,
        slpi.id AS performedItemId,
        slpi.serviceLogId,
        slpi.maintenancePlanItemId, 
        slpi.customItemName,
        mpi.itemName AS predefinedItemName
      FROM service_log_entries sle
      LEFT JOIN service_log_performed_items slpi
        ON slpi.serviceLogId = sle.id
      LEFT JOIN maintenance_plan_items mpi
        ON slpi.maintenancePlanItemId = mpi.id
      WHERE sle.id = ?
      ORDER BY slpi.id ASC
      ''',
      [logId],
    );
    final logs = _mapJoinedServiceLogs(rows);
    return logs.isEmpty ? null : logs.single;
  }

  Future<int> updateServiceLog(
    ServiceLogEntry logEntry,
    List<PerformedItemInput> performedItems,
  ) async {
    final db = await database;
    int count = 0;
    await db.transaction((txn) async {
      // Update the main log entry
      count = await txn.update(
        'service_log_entries',
        logEntry.toMap(),
        where: 'id = ?',
        whereArgs: [logEntry.id],
      );

      // Delete old performed items for this log
      await txn.delete(
        'service_log_performed_items',
        where: 'serviceLogId = ?',
        whereArgs: [logEntry.id],
      );

      // Insert new performed items
      for (var itemInput in performedItems) {
        await txn.insert('service_log_performed_items', {
          'serviceLogId': logEntry.id,
          'maintenancePlanItemId': itemInput.maintenancePlanItemId,
          'customItemName': itemInput.customItemName,
        });
      }
    });
    return count;
  }

  Future<int> deleteServiceLog(int logId) async {
    final db = await database;
    return await db.delete(
      'service_log_entries',
      where: 'id = ?',
      whereArgs: [logId],
    );
  }

  Future<List<ServiceLogPerformedItemLink>> getPerformedItemLinksForVehicle(
    int vehicleId,
  ) async {
    final db = await database;
    _diagnosticReadQueryCount++;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
    SELECT slpi.serviceLogId, slpi.maintenancePlanItemId
    FROM service_log_performed_items slpi
    JOIN service_log_entries sle ON slpi.serviceLogId = sle.id
    WHERE sle.vehicleId = ? AND slpi.maintenancePlanItemId IS NOT NULL
  ''',
      [vehicleId],
    );
    return maps
        .map(
          (map) => ServiceLogPerformedItemLink(
            serviceLogId: map['serviceLogId'] as int,
            maintenancePlanItemId: map['maintenancePlanItemId'] as int,
          ),
        )
        .toList();
  }

  Future<
    ({
      List<MaintenancePlanItem> planItems,
      List<ServiceLogEntry> serviceLogs,
      List<ServiceLogPerformedItemLink> performedItemLinks,
      List<Vehicle> vehicles,
    })
  >
  getPredictionSnapshotRows() async {
    final db = await database;
    return db.transaction((transaction) async {
      _diagnosticReadQueryCount++;
      final vehicleMaps = await transaction.query(
        'vehicles',
        columns: const [
          'id',
          'name',
          'mileage',
          'mileage_last_updated',
          'bought_date',
          'model',
          'plate_number',
          'vin',
          'engine_number',
        ],
        orderBy: 'id DESC',
      );
      _diagnosticReadQueryCount++;
      final planMaps = await transaction.query(
        'maintenance_plan_items',
        where: 'isActive = ?',
        whereArgs: const [1],
        orderBy: 'vehicleId ASC, id ASC',
      );
      _diagnosticReadQueryCount++;
      final logMaps = await transaction.query(
        'service_log_entries',
        orderBy: 'vehicleId ASC, serviceDate DESC, id DESC',
      );
      _diagnosticReadQueryCount++;
      final linkMaps = await transaction.query(
        'service_log_performed_items',
        columns: const ['serviceLogId', 'maintenancePlanItemId'],
        where: 'maintenancePlanItemId IS NOT NULL',
        orderBy: 'serviceLogId ASC, id ASC',
      );

      return (
        vehicles: vehicleMaps.map(Vehicle.fromMap).toList(growable: false),
        planItems: planMaps
            .map(MaintenancePlanItem.fromMap)
            .toList(growable: false),
        serviceLogs: logMaps
            .map(ServiceLogEntry.fromMap)
            .toList(growable: false),
        performedItemLinks: linkMaps
            .map(
              (map) => ServiceLogPerformedItemLink(
                serviceLogId: map['serviceLogId'] as int,
                maintenancePlanItemId: map['maintenancePlanItemId'] as int,
              ),
            )
            .toList(growable: false),
      );
    });
  }

  List<ServiceLogWithItems> _mapJoinedServiceLogs(
    List<Map<String, dynamic>> rows,
  ) {
    final entries = <int, ServiceLogEntry>{};
    final itemsByLogId = <int, List<ServiceLogPerformedItem>>{};

    for (final row in rows) {
      final entry = ServiceLogEntry.fromMap(row);
      final logId = entry.id;
      if (logId == null) continue;
      entries.putIfAbsent(logId, () => entry);
      final performedItemId = row['performedItemId'] as int?;
      if (performedItemId == null) continue;
      itemsByLogId
          .putIfAbsent(logId, () => <ServiceLogPerformedItem>[])
          .add(
            ServiceLogPerformedItem.fromJoinedMap({
              'id': performedItemId,
              'serviceLogId': row['serviceLogId'],
              'maintenancePlanItemId': row['maintenancePlanItemId'],
              'customItemName': row['customItemName'],
              'predefinedItemName': row['predefinedItemName'],
            }),
          );
    }

    return [
      for (final entry in entries.entries)
        ServiceLogWithItems(
          entry: entry.value,
          performedItems: List.unmodifiable(
            itemsByLogId[entry.key] ?? const <ServiceLogPerformedItem>[],
          ),
        ),
    ];
  }

  Future<void> close() async {
    await runExclusiveMaintenance((connection) => connection.close());
  }

  Future<void> _closeDatabase() async {
    final openingDatabase = _openingDatabase;
    if (openingDatabase != null) {
      await openingDatabase;
    }

    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
    }
    _database = null;
  }
}

/// Restricted connection lifecycle access for an exclusive database-file
/// maintenance operation.
class DatabaseMaintenanceConnection {
  DatabaseMaintenanceConnection._(this._databaseHelper);

  final DatabaseHelper _databaseHelper;

  Future<void> close() => _databaseHelper._closeDatabase();

  Future<Database> open() => _databaseHelper._openDatabase();
}
