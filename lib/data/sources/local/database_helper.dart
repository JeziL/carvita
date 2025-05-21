import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:carvita/core/services/prediction_service.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/vehicle.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const String dbName = 'carvita_v1.db';
  static const int _dbVersion = 1;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      // onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vehicles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        mileage REAL NOT NULL,
        bought_date TEXT NOT NULL,
        image BLOB,
        model TEXT,
        plate_number TEXT,
        vin TEXT,
        engine_number TEXT
      )
    ''');

    await db.execute('''
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

    await db.execute('''
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

    await db.execute('''
      CREATE TABLE service_log_performed_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        serviceLogId INTEGER NOT NULL,
        maintenancePlanItemId INTEGER, 
        customItemName TEXT,
        FOREIGN KEY (serviceLogId) REFERENCES service_log_entries (id) ON DELETE CASCADE,
        FOREIGN KEY (maintenancePlanItemId) REFERENCES maintenance_plan_items (id) ON DELETE SET NULL 
      )
    ''');
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
    final List<Map<String, dynamic>> maps = await db.query(
      'vehicles',
      orderBy: 'id DESC',
    );
    if (maps.isEmpty) {
      return [];
    }
    return List.generate(maps.length, (i) => Vehicle.fromMap(maps[i]));
  }

  Future<Vehicle?> getVehicleById(int id) async {
    final db = await database;
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

  Future<int> updateVehicle(Vehicle vehicle) async {
    final db = await database;
    return await db.update(
      'vehicles',
      vehicle.toMap(),
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
  }

  Future<int> deleteVehicle(int id) async {
    final db = await database;
    return await db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
  }

  // --- Maintenance plan CRUD ---

  Future<int> insertMaintenancePlanItem(MaintenancePlanItem item) async {
    final db = await database;
    Map<String, dynamic> itemMap = item.toMap();
    itemMap.remove('id'); // make SQLite auto-increment
    return await db.insert(
      'maintenance_plan_items',
      itemMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MaintenancePlanItem>> getMaintenancePlanItemsForVehicle(
    int vehicleId,
  ) async {
    final db = await database;
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
    return await db.update(
      'maintenance_plan_items',
      item.toMap(),
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
    return await db.delete(
      'maintenance_plan_items',
      where: 'id = ?',
      whereArgs: [itemId],
    );
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
    final List<Map<String, dynamic>> logMaps = await db.query(
      'service_log_entries',
      where: 'vehicleId = ?',
      whereArgs: [vehicleId],
      orderBy: 'serviceDate DESC, id DESC',
    );

    List<ServiceLogWithItems> logsWithItems = [];
    for (var logMap in logMaps) {
      final entry = ServiceLogEntry.fromMap(logMap);
      final List<Map<String, dynamic>> performedItemMaps = await db.rawQuery(
        '''
        SELECT 
          slpi.id, 
          slpi.serviceLogId, 
          slpi.maintenancePlanItemId, 
          slpi.customItemName,
          mpi.itemName as predefinedItemName 
        FROM service_log_performed_items slpi
        LEFT JOIN maintenance_plan_items mpi ON slpi.maintenancePlanItemId = mpi.id
        WHERE slpi.serviceLogId = ?
      ''',
        [entry.id],
      );

      List<String> displayNames =
          performedItemMaps.map((map) {
            return map['customItemName'] as String? ??
                map['predefinedItemName'] as String? ??
                'Unkonwn Item';
          }).toList();

      logsWithItems.add(
        ServiceLogWithItems(
          entry: entry,
          performedItemDisplayNames: displayNames,
        ),
      );
    }
    return logsWithItems;
  }

  Future<ServiceLogWithItems?> getServiceLogByIdWithItems(int logId) async {
    final db = await database;
    final List<Map<String, dynamic>> logMaps = await db.query(
      'service_log_entries',
      where: 'id = ?',
      whereArgs: [logId],
    );

    if (logMaps.isEmpty) return null;

    final entry = ServiceLogEntry.fromMap(logMaps.first);
    final List<Map<String, dynamic>> performedItemMaps = await db.rawQuery(
      '''
      SELECT 
        slpi.id, 
        slpi.serviceLogId, 
        slpi.maintenancePlanItemId, 
        slpi.customItemName,
        mpi.itemName as predefinedItemName 
      FROM service_log_performed_items slpi
      LEFT JOIN maintenance_plan_items mpi ON slpi.maintenancePlanItemId = mpi.id
      WHERE slpi.serviceLogId = ?
    ''',
      [entry.id],
    );

    List<String> displayNames =
        performedItemMaps.map((map) {
          return map['customItemName'] as String? ??
              map['predefinedItemName'] as String? ??
              'Unknown Item';
        }).toList();

    return ServiceLogWithItems(
      entry: entry,
      performedItemDisplayNames: displayNames,
    );
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

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}
