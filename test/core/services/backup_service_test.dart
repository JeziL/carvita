import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:carvita/core/services/backup_service.dart';
import 'package:carvita/data/sources/local/database_helper.dart';

void main() {
  sqfliteFfiInit();

  late Directory testDirectory;
  late Directory databaseDirectory;
  late Directory exportDirectory;
  late String liveDatabasePath;
  late _TestDatabaseController controller;
  late BackupService backupService;

  setUp(() async {
    testDirectory = await Directory.systemTemp.createTemp(
      'carvita_backup_service_test_',
    );
    databaseDirectory = Directory(path.join(testDirectory.path, 'databases'));
    exportDirectory = Directory(path.join(testDirectory.path, 'exports'));
    await databaseDirectory.create(recursive: true);
    await exportDirectory.create(recursive: true);

    liveDatabasePath = path.join(databaseDirectory.path, DatabaseHelper.dbName);
    controller = _TestDatabaseController(
      factory: databaseFactoryFfi,
      databasePath: liveDatabasePath,
    );
    backupService = BackupService(
      databaseController: controller,
      sqliteFactory: databaseFactoryFfi,
      databaseDirectoryProvider: () async => databaseDirectory.path,
      temporaryDirectoryProvider: () async => exportDirectory,
      clock: () => DateTime(2026, 7, 26, 12, 34, 56, 789),
    );

    final database = await controller.open();
    await _insertVehicle(database, name: 'Current vehicle');
  });

  tearDown(() async {
    await controller.close();
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  test(
    'export creates an independent valid snapshot and reopens live DB',
    () async {
      final snapshotPath = await backupService.createExportSnapshot();

      expect(File(snapshotPath).existsSync(), isTrue);
      expect(controller.isOpen, isTrue);

      final snapshotDatabase = await databaseFactoryFfi.openDatabase(
        snapshotPath,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      addTearDown(snapshotDatabase.close);

      expect(await _vehicleNames(snapshotDatabase), ['Current vehicle']);

      final liveDatabase = await controller.open();
      await liveDatabase.update(
        'vehicles',
        {'name': 'Changed after export'},
        where: 'name = ?',
        whereArgs: ['Current vehicle'],
      );

      expect(await _vehicleNames(snapshotDatabase), ['Current vehicle']);
      expect(controller.closeCount, 1);
    },
  );

  test(
    'restore validates, atomically replaces, and reopens the database',
    () async {
      final candidatePath = path.join(testDirectory.path, 'candidate.db');
      await _createCandidateDatabase(
        candidatePath,
        vehicleName: 'Restored vehicle',
      );

      await backupService.restoreDatabase(candidatePath);

      expect(controller.isOpen, isTrue);
      expect(await _vehicleNames(await controller.open()), [
        'Restored vehicle',
      ]);
      expect(
        databaseDirectory
            .listSync()
            .whereType<File>()
            .map((file) => path.basename(file.path))
            .where(
              (name) =>
                  name.contains('restore-staging') || name.contains('rollback'),
            ),
        isEmpty,
      );
    },
  );

  test(
    'non-SQLite input is rejected before the live connection closes',
    () async {
      final invalidPath = path.join(testDirectory.path, 'not-a-database.db');
      await File(invalidPath).writeAsString('not a SQLite database');
      final closeCountBeforeRestore = controller.closeCount;

      await expectLater(
        backupService.restoreDatabase(invalidPath),
        throwsA(isA<InvalidBackupException>()),
      );

      expect(controller.closeCount, closeCountBeforeRestore);
      expect(await _vehicleNames(await controller.open()), ['Current vehicle']);
    },
  );

  test(
    'an unsupported schema version is rejected before replacement',
    () async {
      final candidatePath = path.join(testDirectory.path, 'future-schema.db');
      await _createCandidateDatabase(
        candidatePath,
        vehicleName: 'Future vehicle',
      );
      final candidateDatabase = await databaseFactoryFfi.openDatabase(
        candidatePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await candidateDatabase.execute('PRAGMA user_version = 2');
      await candidateDatabase.close();
      final closeCountBeforeRestore = controller.closeCount;

      await expectLater(
        backupService.restoreDatabase(candidatePath),
        throwsA(isA<InvalidBackupException>()),
      );

      expect(controller.closeCount, closeCountBeforeRestore);
      expect(await _vehicleNames(await controller.open()), ['Current vehicle']);
    },
  );

  test(
    'a failed reopen rolls back byte-for-byte and leaves old data readable',
    () async {
      final candidatePath = path.join(testDirectory.path, 'candidate.db');
      await _createCandidateDatabase(
        candidatePath,
        vehicleName: 'Restored vehicle',
      );

      await controller.close();
      final originalBytes = await File(liveDatabasePath).readAsBytes();
      await controller.open();
      controller.failNextOpen = true;

      await expectLater(
        backupService.restoreDatabase(candidatePath),
        throwsA(
          isA<BackupRestoreException>().having(
            (error) => error.message,
            'message',
            contains('previous database was restored'),
          ),
        ),
      );

      final recoveredBytes = await File(liveDatabasePath).readAsBytes();
      expect(recoveredBytes, originalBytes);
      expect(controller.isOpen, isTrue);
      expect(await _vehicleNames(await controller.open()), ['Current vehicle']);
      expect(File('$liveDatabasePath-wal').existsSync(), isFalse);
      expect(File('$liveDatabasePath-shm').existsSync(), isFalse);
    },
  );

  test('a database missing required tables is rejected', () async {
    final incompletePath = path.join(testDirectory.path, 'incomplete.db');
    final database = await databaseFactoryFfi.openDatabase(
      incompletePath,
      options: OpenDatabaseOptions(
        version: BackupService.supportedSchemaVersion,
        onCreate: (database, _) async {
          await database.execute(
            'CREATE TABLE vehicles (id INTEGER PRIMARY KEY, name TEXT)',
          );
        },
      ),
    );
    await database.close();

    await expectLater(
      backupService.restoreDatabase(incompletePath),
      throwsA(isA<InvalidBackupException>()),
    );
    expect(await _vehicleNames(await controller.open()), ['Current vehicle']);
  });

  test('a database with a user-defined view is rejected', () async {
    final candidatePath = path.join(testDirectory.path, 'with-view.db');
    await _createCandidateDatabase(
      candidatePath,
      vehicleName: 'Restored vehicle',
    );
    final candidateDatabase = await databaseFactoryFfi.openDatabase(
      candidatePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await candidateDatabase.execute(
      'CREATE VIEW vehicle_names AS SELECT name FROM vehicles',
    );
    await candidateDatabase.close();

    await expectLater(
      backupService.restoreDatabase(candidatePath),
      throwsA(isA<InvalidBackupException>()),
    );
    expect(await _vehicleNames(await controller.open()), ['Current vehicle']);
  });

  test(
    'the Android platform android_metadata table remains compatible',
    () async {
      final candidatePath = path.join(
        testDirectory.path,
        'android-database.db',
      );
      await _createCandidateDatabase(
        candidatePath,
        vehicleName: 'Android restored vehicle',
      );
      final candidateDatabase = await databaseFactoryFfi.openDatabase(
        candidatePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await candidateDatabase.execute(
        'CREATE TABLE android_metadata (locale TEXT)',
      );
      await candidateDatabase.insert('android_metadata', {'locale': 'en_US'});
      await candidateDatabase.close();

      await backupService.restoreDatabase(candidatePath);

      expect(await _vehicleNames(await controller.open()), [
        'Android restored vehicle',
      ]);
    },
  );

  test('an extra user table is rejected', () async {
    final candidatePath = path.join(testDirectory.path, 'extra-table.db');
    await _createCandidateDatabase(
      candidatePath,
      vehicleName: 'Restored vehicle',
    );
    final candidateDatabase = await databaseFactoryFfi.openDatabase(
      candidatePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await candidateDatabase.execute('CREATE TABLE injected_data (value TEXT)');
    await candidateDatabase.close();

    await expectLater(
      backupService.restoreDatabase(candidatePath),
      throwsA(isA<InvalidBackupException>()),
    );
    expect(await _vehicleNames(await controller.open()), ['Current vehicle']);
  });

  test('snapshot cleanup never obscures an earlier export result', () async {
    final cleanupService = BackupService(
      databaseController: controller,
      sqliteFactory: databaseFactoryFfi,
      databaseDirectoryProvider: () async => databaseDirectory.path,
      temporaryDirectoryProvider: () async {
        throw const FileSystemException('Injected cleanup failure');
      },
    );

    await expectLater(
      cleanupService.deleteExportSnapshot('/unused/carvita_backup_test.db'),
      completes,
    );
  });
}

class _TestDatabaseController
    implements BackupDatabaseController, BackupDatabaseConnection {
  _TestDatabaseController({required this.factory, required this.databasePath});

  final DatabaseFactory factory;
  final String databasePath;

  Database? _database;
  int closeCount = 0;
  bool failNextOpen = false;

  bool get isOpen => _database?.isOpen ?? false;

  @override
  Future<void> close() async {
    closeCount++;
    final database = _database;
    _database = null;
    if (database != null && database.isOpen) {
      await database.close();
    }
  }

  @override
  Future<Database> open() async {
    final currentDatabase = _database;
    if (currentDatabase != null && currentDatabase.isOpen) {
      return currentDatabase;
    }
    if (failNextOpen) {
      failNextOpen = false;
      throw StateError('Injected database open failure');
    }

    final openedDatabase = await factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: BackupService.supportedSchemaVersion,
        onCreate: _createSchema,
      ),
    );
    _database = openedDatabase;
    return openedDatabase;
  }

  @override
  Future<T> runExclusive<T>(
    Future<T> Function(BackupDatabaseConnection connection) operation,
  ) {
    return operation(this);
  }
}

Future<void> _createCandidateDatabase(
  String databasePath, {
  required String vehicleName,
}) async {
  final database = await databaseFactoryFfi.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(
      version: BackupService.supportedSchemaVersion,
      onCreate: _createSchema,
    ),
  );
  await _insertVehicle(database, name: vehicleName);
  await database.close();
}

Future<void> _createSchema(Database database, int version) async {
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
      isActive INTEGER DEFAULT 1 NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE service_log_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      vehicleId INTEGER NOT NULL,
      serviceDate TEXT NOT NULL,
      mileageAtService REAL NOT NULL,
      cost REAL,
      notes TEXT
    )
  ''');
  await database.execute('''
    CREATE TABLE service_log_performed_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      serviceLogId INTEGER NOT NULL,
      maintenancePlanItemId INTEGER,
      customItemName TEXT
    )
  ''');
}

Future<void> _insertVehicle(Database database, {required String name}) async {
  await database.insert('vehicles', {
    'name': name,
    'mileage': 1234.0,
    'mileage_last_updated': '2026-07-26T00:00:00.000',
    'bought_date': '2025-01-01T00:00:00.000',
  });
}

Future<List<String>> _vehicleNames(Database database) async {
  final rows = await database.query('vehicles', orderBy: 'id');
  return rows.map((row) => row['name']! as String).toList(growable: false);
}
