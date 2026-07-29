import 'package:sqflite/sqflite.dart';

final class DatabaseSchema {
  const DatabaseSchema._();

  static const int legacyVersion = 1;
  static const int currentVersion = 2;
  static const Set<int> restorableVersions = {legacyVersion, currentVersion};

  static const String legacyBaselineDateDefault = '1970-01-01T00:00:00.000';

  static const String planLookupIndex =
      'idx_maintenance_plan_active_vehicle_id';
  static const String serviceLogLookupIndex = 'idx_service_log_vehicle_date_id';
  static const String performedItemLogIndex = 'idx_performed_item_log_id';
  static const String performedItemPlanIndex = 'idx_performed_item_plan_id';

  static const Set<String> indexNames = {
    planLookupIndex,
    serviceLogLookupIndex,
    performedItemLogIndex,
    performedItemPlanIndex,
  };

  static Future<void> configure(Database database) async {
    await database.execute('PRAGMA foreign_keys = ON');
    final rows = await database.rawQuery('PRAGMA foreign_keys');
    final enabled = rows.isNotEmpty && rows.first.values.first == 1;
    if (!enabled) {
      throw StateError('SQLite foreign key enforcement could not be enabled.');
    }
  }

  static Future<void> create(Database database, int version) async {
    if (version != currentVersion) {
      throw UnsupportedDatabaseVersionException(
        oldVersion: 0,
        newVersion: version,
      );
    }

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
        baselineDate TEXT NOT NULL DEFAULT '$legacyBaselineDateDefault',
        baselineMileage REAL NOT NULL DEFAULT 0,
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

    await _createIndexes(database);
  }

  static Future<void> upgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < legacyVersion ||
        oldVersion > newVersion ||
        newVersion > currentVersion) {
      throw UnsupportedDatabaseVersionException(
        oldVersion: oldVersion,
        newVersion: newVersion,
      );
    }

    if (oldVersion < 2 && newVersion >= 2) {
      await _upgradeV1ToV2(database);
    }
  }

  static Future<DatabaseConsistencyReport> audit(
    DatabaseExecutor database,
  ) async {
    final columns = await _columnNames(database, 'maintenance_plan_items');
    final hasBaselines =
        columns.contains('baselineDate') && columns.contains('baselineMileage');

    final vehicleRows = await database.rawQuery(
      'SELECT mileage, mileage_last_updated, bought_date FROM vehicles',
    );
    final invalidVehicleValues = vehicleRows.where((row) {
      return row['mileage'] is! num ||
          !_isValidDate(row['mileage_last_updated']) ||
          !_isValidDate(row['bought_date']);
    }).length;

    final serviceLogRows = await database.rawQuery(
      'SELECT serviceDate, mileageAtService FROM service_log_entries',
    );
    final invalidServiceLogValues = serviceLogRows.where((row) {
      return row['mileageAtService'] is! num ||
          !_isValidDate(row['serviceDate']);
    }).length;

    var invalidPlanBaselineValues = 0;
    if (hasBaselines) {
      final baselineRows = await database.rawQuery(
        'SELECT baselineDate, baselineMileage FROM maintenance_plan_items',
      );
      invalidPlanBaselineValues = baselineRows.where((row) {
        return row['baselineMileage'] is! num ||
            !_isValidDate(row['baselineDate']);
      }).length;
    }

    return DatabaseConsistencyReport(
      orphanPlanItems: await _count(database, '''
        SELECT COUNT(*)
        FROM maintenance_plan_items plan
        LEFT JOIN vehicles vehicle ON vehicle.id = plan.vehicleId
        WHERE vehicle.id IS NULL
      '''),
      orphanServiceLogs: await _count(database, '''
        SELECT COUNT(*)
        FROM service_log_entries log
        LEFT JOIN vehicles vehicle ON vehicle.id = log.vehicleId
        WHERE vehicle.id IS NULL
      '''),
      performedItemsMissingLog: await _count(database, '''
        SELECT COUNT(*)
        FROM service_log_performed_items performed
        LEFT JOIN service_log_entries log ON log.id = performed.serviceLogId
        WHERE log.id IS NULL
      '''),
      performedItemsMissingPlan: await _count(database, '''
        SELECT COUNT(*)
        FROM service_log_performed_items performed
        LEFT JOIN maintenance_plan_items plan
          ON plan.id = performed.maintenancePlanItemId
        WHERE performed.maintenancePlanItemId IS NOT NULL
          AND plan.id IS NULL
      '''),
      crossVehiclePlanLinks: await _count(database, '''
        SELECT COUNT(*)
        FROM service_log_performed_items performed
        JOIN service_log_entries log ON log.id = performed.serviceLogId
        JOIN maintenance_plan_items plan
          ON plan.id = performed.maintenancePlanItemId
        WHERE log.vehicleId <> plan.vehicleId
      '''),
      ambiguousPerformedItems: await _count(database, '''
        SELECT COUNT(*)
        FROM service_log_performed_items
        WHERE maintenancePlanItemId IS NOT NULL
          AND NULLIF(TRIM(customItemName), '') IS NOT NULL
      '''),
      unidentifiedPerformedItems: await _count(database, '''
        SELECT COUNT(*)
        FROM service_log_performed_items
        WHERE maintenancePlanItemId IS NULL
          AND NULLIF(TRIM(customItemName), '') IS NULL
      '''),
      invalidVehicleValues: invalidVehicleValues,
      invalidServiceLogValues: invalidServiceLogValues,
      invalidPlanBaselineValues: invalidPlanBaselineValues,
      foreignKeyDefinitionIssues: await _foreignKeyDefinitionIssues(database),
    );
  }

  static Future<void> _upgradeV1ToV2(Database database) async {
    final before = await audit(database);
    if (before.hasBlockingSchemaOrValueErrors) {
      throw DatabaseMigrationException(
        'The v1 database contains invalid schema, dates, or numeric values.',
        report: before,
      );
    }

    await _repairRelationships(database);

    final columns = await _columnNames(database, 'maintenance_plan_items');
    if (!columns.contains('baselineDate')) {
      await database.execute('''
        ALTER TABLE maintenance_plan_items
        ADD COLUMN baselineDate TEXT NOT NULL
          DEFAULT '$legacyBaselineDateDefault'
      ''');
    }
    if (!columns.contains('baselineMileage')) {
      await database.execute('''
        ALTER TABLE maintenance_plan_items
        ADD COLUMN baselineMileage REAL NOT NULL DEFAULT 0
      ''');
    }

    await database.rawUpdate(
      '''
      UPDATE maintenance_plan_items
      SET baselineDate = (
        SELECT vehicle.bought_date
        FROM vehicles vehicle
        WHERE vehicle.id = maintenance_plan_items.vehicleId
      )
      WHERE baselineDate = ? OR baselineDate IS NULL
    ''',
      [legacyBaselineDateDefault],
    );

    await _createIndexes(database);
    await _verifyForeignKeys(database);

    final after = await audit(database);
    if (!after.isClean) {
      throw DatabaseMigrationException(
        'The v1 database could not be normalized safely.',
        report: after,
      );
    }
  }

  static Future<void> _repairRelationships(Database database) async {
    await database.rawDelete('''
      DELETE FROM service_log_performed_items
      WHERE NOT EXISTS (
        SELECT 1
        FROM service_log_entries log
        WHERE log.id = service_log_performed_items.serviceLogId
      )
    ''');

    // A custom name is the identity currently shown to the user, so it wins
    // over an accidentally retained plan link.
    await database.rawUpdate('''
      UPDATE service_log_performed_items
      SET maintenancePlanItemId = NULL
      WHERE maintenancePlanItemId IS NOT NULL
        AND NULLIF(TRIM(customItemName), '') IS NOT NULL
    ''');

    // Preserve the visible plan name as a custom historical item when the
    // linked plan belongs to another vehicle or has lost its vehicle.
    await database.rawUpdate('''
      UPDATE service_log_performed_items
      SET customItemName = (
            SELECT plan.itemName
            FROM maintenance_plan_items plan
            WHERE plan.id =
              service_log_performed_items.maintenancePlanItemId
          ),
          maintenancePlanItemId = NULL
      WHERE maintenancePlanItemId IS NOT NULL
        AND EXISTS (
          SELECT 1
          FROM maintenance_plan_items plan
          JOIN service_log_entries log
            ON log.id = service_log_performed_items.serviceLogId
          WHERE plan.id =
              service_log_performed_items.maintenancePlanItemId
            AND (
              plan.vehicleId <> log.vehicleId
              OR NOT EXISTS (
                SELECT 1
                FROM vehicles vehicle
                WHERE vehicle.id = plan.vehicleId
              )
            )
        )
    ''');

    await database.rawUpdate('''
      UPDATE service_log_performed_items
      SET maintenancePlanItemId = NULL
      WHERE maintenancePlanItemId IS NOT NULL
        AND NULLIF(TRIM(customItemName), '') IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM maintenance_plan_items plan
          WHERE plan.id =
            service_log_performed_items.maintenancePlanItemId
        )
    ''');

    await database.rawDelete('''
      DELETE FROM service_log_performed_items
      WHERE maintenancePlanItemId IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM maintenance_plan_items plan
          WHERE plan.id =
            service_log_performed_items.maintenancePlanItemId
        )
    ''');

    await database.rawDelete('''
      DELETE FROM service_log_performed_items
      WHERE maintenancePlanItemId IS NULL
        AND NULLIF(TRIM(customItemName), '') IS NULL
    ''');

    await database.rawDelete('''
      DELETE FROM service_log_entries
      WHERE NOT EXISTS (
        SELECT 1
        FROM vehicles vehicle
        WHERE vehicle.id = service_log_entries.vehicleId
      )
    ''');

    await database.rawDelete('''
      DELETE FROM maintenance_plan_items
      WHERE NOT EXISTS (
        SELECT 1
        FROM vehicles vehicle
        WHERE vehicle.id = maintenance_plan_items.vehicleId
      )
    ''');
  }

  static Future<void> _createIndexes(Database database) async {
    await database.execute('''
      CREATE INDEX IF NOT EXISTS $planLookupIndex
      ON maintenance_plan_items (isActive, vehicleId, id)
    ''');
    await database.execute('''
      CREATE INDEX IF NOT EXISTS $serviceLogLookupIndex
      ON service_log_entries (vehicleId, serviceDate DESC, id DESC)
    ''');
    await database.execute('''
      CREATE INDEX IF NOT EXISTS $performedItemLogIndex
      ON service_log_performed_items (serviceLogId, id)
    ''');
    await database.execute('''
      CREATE INDEX IF NOT EXISTS $performedItemPlanIndex
      ON service_log_performed_items (maintenancePlanItemId, serviceLogId)
    ''');
  }

  static Future<void> _verifyForeignKeys(Database database) async {
    final rows = await database.rawQuery('PRAGMA foreign_key_check');
    if (rows.isNotEmpty) {
      throw DatabaseMigrationException(
        'SQLite foreign key validation failed after migration.',
      );
    }
  }

  static Future<int> _foreignKeyDefinitionIssues(
    DatabaseExecutor database,
  ) async {
    var issues = 0;
    final planForeignKeys = await database.rawQuery(
      'PRAGMA foreign_key_list("maintenance_plan_items")',
    );
    if (!_containsForeignKey(
      planForeignKeys,
      from: 'vehicleId',
      table: 'vehicles',
      to: 'id',
      onDelete: 'CASCADE',
    )) {
      issues++;
    }

    final logForeignKeys = await database.rawQuery(
      'PRAGMA foreign_key_list("service_log_entries")',
    );
    if (!_containsForeignKey(
      logForeignKeys,
      from: 'vehicleId',
      table: 'vehicles',
      to: 'id',
      onDelete: 'CASCADE',
    )) {
      issues++;
    }

    final performedForeignKeys = await database.rawQuery(
      'PRAGMA foreign_key_list("service_log_performed_items")',
    );
    if (!_containsForeignKey(
      performedForeignKeys,
      from: 'serviceLogId',
      table: 'service_log_entries',
      to: 'id',
      onDelete: 'CASCADE',
    )) {
      issues++;
    }
    if (!_containsForeignKey(
      performedForeignKeys,
      from: 'maintenancePlanItemId',
      table: 'maintenance_plan_items',
      to: 'id',
      onDelete: 'SET NULL',
    )) {
      issues++;
    }
    return issues;
  }

  static bool _containsForeignKey(
    List<Map<String, Object?>> rows, {
    required String from,
    required String table,
    required String to,
    required String onDelete,
  }) {
    return rows.any(
      (row) =>
          row['from'] == from &&
          row['table'] == table &&
          row['to'] == to &&
          row['on_delete']?.toString().toUpperCase() == onDelete,
    );
  }

  static Future<Set<String>> _columnNames(
    DatabaseExecutor database,
    String table,
  ) async {
    final rows = await database.rawQuery('PRAGMA table_info("$table")');
    return rows.map((row) => row['name']).whereType<String>().toSet();
  }

  static Future<int> _count(DatabaseExecutor database, String query) async {
    final rows = await database.rawQuery(query);
    final value = rows.first.values.first;
    return value is int ? value : (value as num).toInt();
  }

  static bool _isValidDate(Object? value) {
    return value is String && DateTime.tryParse(value) != null;
  }
}

final class DatabaseConsistencyReport {
  const DatabaseConsistencyReport({
    required this.orphanPlanItems,
    required this.orphanServiceLogs,
    required this.performedItemsMissingLog,
    required this.performedItemsMissingPlan,
    required this.crossVehiclePlanLinks,
    required this.ambiguousPerformedItems,
    required this.unidentifiedPerformedItems,
    required this.invalidVehicleValues,
    required this.invalidServiceLogValues,
    required this.invalidPlanBaselineValues,
    required this.foreignKeyDefinitionIssues,
  });

  final int orphanPlanItems;
  final int orphanServiceLogs;
  final int performedItemsMissingLog;
  final int performedItemsMissingPlan;
  final int crossVehiclePlanLinks;
  final int ambiguousPerformedItems;
  final int unidentifiedPerformedItems;
  final int invalidVehicleValues;
  final int invalidServiceLogValues;
  final int invalidPlanBaselineValues;
  final int foreignKeyDefinitionIssues;

  bool get hasBlockingValueErrors =>
      invalidVehicleValues > 0 ||
      invalidServiceLogValues > 0 ||
      invalidPlanBaselineValues > 0;

  bool get hasBlockingSchemaOrValueErrors =>
      hasBlockingValueErrors || foreignKeyDefinitionIssues > 0;

  bool get hasRelationshipIssues =>
      orphanPlanItems > 0 ||
      orphanServiceLogs > 0 ||
      performedItemsMissingLog > 0 ||
      performedItemsMissingPlan > 0 ||
      crossVehiclePlanLinks > 0 ||
      ambiguousPerformedItems > 0 ||
      unidentifiedPerformedItems > 0;

  bool get isClean => !hasBlockingSchemaOrValueErrors && !hasRelationshipIssues;
}

class DatabaseMigrationException implements Exception {
  const DatabaseMigrationException(this.message, {this.report});

  final String message;
  final DatabaseConsistencyReport? report;

  @override
  String toString() => 'DatabaseMigrationException: $message';
}

class UnsupportedDatabaseVersionException extends DatabaseMigrationException {
  UnsupportedDatabaseVersionException({
    required this.oldVersion,
    required this.newVersion,
  }) : super(
         'Unsupported database migration from version $oldVersion '
         'to $newVersion.',
       );

  final int oldVersion;
  final int newVersion;
}
