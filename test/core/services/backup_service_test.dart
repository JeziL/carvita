import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:carvita/application/ports/backup_preferences_port.dart';
import 'package:carvita/core/services/backup_service.dart';
import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/data/sources/local/database_helper.dart';
import 'package:carvita/data/sources/local/database_schema.dart';

void main() {
  sqfliteFfiInit();

  late Directory testDirectory;
  late Directory databaseDirectory;
  late Directory exportDirectory;
  late String liveDatabasePath;
  late _TestDatabaseController controller;
  late BackupService backupService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'locale_language_code': 'de',
      'theme_preference': 'dark',
      'custom_theme_seed_color': 0xff123456,
      'mileage_unit': 'mi',
      'default_vehicle_id': 42,
      'notifications_enabled': true,
      'reminder_lead_time_days': 14,
      'due_reminder_threshold': 'month',
      'due_reminder_item_count': 5,
    });
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
      preferences: PreferencesService(),
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
    'versioned export restores an independent database and preferences',
    () async {
      final snapshotPath = await backupService.createExportSnapshot(
        applicationVersion: '1.1.0+8',
      );

      expect(File(snapshotPath).existsSync(), isTrue);
      expect(path.extension(snapshotPath), '.cvbackup');
      expect(controller.isOpen, isTrue);
      debugPrint(
        'Versioned backup size: ${await File(snapshotPath).length()} bytes; '
        'database size: ${await File(liveDatabasePath).length()} bytes',
      );

      final archive = ZipDecoder().decodeBytes(
        await File(snapshotPath).readAsBytes(),
      );
      final manifest =
          jsonDecode(utf8.decode(archive.find('manifest.json')!.readBytes()!))
              as Map<String, dynamic>;
      expect(manifest['formatVersion'], BackupService.backupFormatVersion);
      expect(manifest['databaseSchemaVersion'], DatabaseHelper.schemaVersion);
      expect(manifest['applicationVersion'], '1.1.0+8');
      expect(manifest['contents'], hasLength(2));

      final liveDatabase = await controller.open();
      await liveDatabase.update(
        'vehicles',
        {'name': 'Changed after export'},
        where: 'name = ?',
        whereArgs: ['Current vehicle'],
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('locale_language_code', 'ja');
      await preferences.setBool('notifications_enabled', false);

      await backupService.restoreDatabase(snapshotPath);

      expect(await _vehicleNames(await controller.open()), ['Current vehicle']);
      expect(preferences.getString('locale_language_code'), 'de');
      expect(preferences.getBool('notifications_enabled'), isTrue);
      expect(controller.closeCount, greaterThanOrEqualTo(2));
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
      await _expectPreferencesUnchanged();
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

  test('unknown package format is rejected before replacement', () async {
    final packagePath = await backupService.createExportSnapshot();
    final futurePackagePath = await _rewritePackageEntry(
      packagePath,
      path.join(testDirectory.path, 'future.cvbackup'),
      'manifest.json',
      (bytes) {
        final manifest = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        manifest['formatVersion'] = 99;
        return utf8.encode(jsonEncode(manifest));
      },
    );
    final closeCountBeforeRestore = controller.closeCount;

    await expectLater(
      backupService.restoreDatabase(futurePackagePath),
      throwsA(isA<UnsupportedBackupFormatException>()),
    );

    expect(controller.closeCount, closeCountBeforeRestore);
    expect(await _vehicleNames(await controller.open()), ['Current vehicle']);
  });

  test('content checksum mismatch is rejected before replacement', () async {
    final packagePath = await backupService.createExportSnapshot();
    final tamperedPackagePath = await _rewritePackageEntry(
      packagePath,
      path.join(testDirectory.path, 'tampered.cvbackup'),
      'database/${DatabaseHelper.dbName}',
      (bytes) {
        final tampered = [...bytes];
        tampered[tampered.length - 1] ^= 0xff;
        return tampered;
      },
    );
    final closeCountBeforeRestore = controller.closeCount;

    await expectLater(
      backupService.restoreDatabase(tamperedPackagePath),
      throwsA(isA<InvalidBackupException>()),
    );

    expect(controller.closeCount, closeCountBeforeRestore);
    expect(await _vehicleNames(await controller.open()), ['Current vehicle']);
  });

  test('preference commit failure rolls the database back', () async {
    final packagePath = await backupService.createExportSnapshot();
    final liveDatabase = await controller.open();
    await liveDatabase.update(
      'vehicles',
      {'name': 'Keep after failed restore'},
      where: 'name = ?',
      whereArgs: ['Current vehicle'],
    );
    final failingService = BackupService(
      databaseController: controller,
      sqliteFactory: databaseFactoryFfi,
      databaseDirectoryProvider: () async => databaseDirectory.path,
      temporaryDirectoryProvider: () async => exportDirectory,
      preferences: const _FailingBackupPreferences(),
    );

    await expectLater(
      failingService.restoreDatabase(packagePath),
      throwsA(isA<BackupRestoreException>()),
    );

    expect(await _vehicleNames(await controller.open()), [
      'Keep after failed restore',
    ]);
  });

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
      await candidateDatabase.execute(
        'PRAGMA user_version = ${DatabaseSchema.currentVersion + 1}',
      );
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
      await _expectPreferencesUnchanged();
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

  test('a v1 database without official foreign keys is rejected', () async {
    final candidatePath = path.join(
      testDirectory.path,
      'missing-foreign-keys.db',
    );
    final candidate = await databaseFactoryFfi.openDatabase(
      candidatePath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.legacyVersion,
        singleInstance: false,
        onCreate: _createLegacySchemaWithoutForeignKeys,
      ),
    );
    await _insertVehicle(candidate, name: 'Unconstrained vehicle');
    await candidate.close();
    final closeCountBeforeRestore = controller.closeCount;

    await expectLater(
      backupService.restoreDatabase(candidatePath),
      throwsA(isA<InvalidBackupException>()),
    );

    expect(controller.closeCount, closeCountBeforeRestore);
    expect(await _vehicleNames(await controller.open()), ['Current vehicle']);
  });

  test('a v2 database with orphan relationships is rejected', () async {
    final candidatePath = path.join(testDirectory.path, 'orphan-v2.db');
    final candidate = await databaseFactoryFfi.openDatabase(
      candidatePath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.currentVersion,
        singleInstance: false,
        onCreate: DatabaseSchema.create,
      ),
    );
    await candidate.insert('maintenance_plan_items', {
      'vehicleId': 999,
      'itemName': 'Orphan',
      'intervalTimeMonths': 12,
      'isActive': 1,
      'baselineDate': '2026-07-29T00:00:00.000',
      'baselineMileage': 0.0,
    });
    await candidate.close();
    final closeCountBeforeRestore = controller.closeCount;

    await expectLater(
      backupService.restoreDatabase(candidatePath),
      throwsA(isA<InvalidBackupException>()),
    );

    expect(controller.closeCount, closeCountBeforeRestore);
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

  test(
    'provided bare v1 backup restores and migrates without preferences',
    () async {
      final fixturePath = path.join(
        Directory.current.path,
        'test',
        'fixtures',
        'database',
        'carvita_v1.db',
      );

      await backupService.restoreDatabase(fixturePath);

      final restored = await controller.open();
      expect(
        (await restored.rawQuery('PRAGMA user_version')).single.values.single,
        DatabaseSchema.currentVersion,
      );
      expect(await restored.query('vehicles'), hasLength(1));
      expect(await restored.query('maintenance_plan_items'), hasLength(9));
      expect(await restored.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await _expectPreferencesUnchanged();
    },
  );

  test('versioned v1 package restores preferences then migrates', () async {
    final fixturePath = path.join(
      Directory.current.path,
      'test',
      'fixtures',
      'database',
      'carvita_v1.db',
    );
    final packagePath = path.join(testDirectory.path, 'legacy-v1.cvbackup');
    await _createLegacyPackage(
      databasePath: fixturePath,
      packagePath: packagePath,
      preferences: const {
        'locale_language_code': 'ja',
        'notifications_enabled': false,
      },
    );

    await backupService.restoreDatabase(packagePath);

    final restored = await controller.open();
    expect(
      (await restored.rawQuery('PRAGMA user_version')).single.values.single,
      DatabaseSchema.currentVersion,
    );
    expect(await restored.query('service_log_entries'), hasLength(12));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('locale_language_code'), 'ja');
    expect(preferences.getBool('notifications_enabled'), isFalse);
  });
}

Future<void> _createLegacyPackage({
  required String databasePath,
  required String packagePath,
  required Map<String, Object> preferences,
}) async {
  final databaseBytes = await File(databasePath).readAsBytes();
  final preferencesBytes = utf8.encode(
    jsonEncode({
      'version': BackupService.backupPreferencesVersion,
      'values': preferences,
    }),
  );
  Map<String, Object> describe(List<int> bytes) => {
    'size': bytes.length,
    'sha256': sha256.convert(bytes).toString(),
  };
  final databaseEntry = 'database/${DatabaseHelper.dbName}';
  final manifestBytes = utf8.encode(
    jsonEncode({
      'formatVersion': BackupService.backupFormatVersion,
      'databaseSchemaVersion': DatabaseSchema.legacyVersion,
      'applicationVersion': '1.1.0+8',
      'createdAt': '2026-07-28T00:00:00.000Z',
      'contents': {
        databaseEntry: describe(databaseBytes),
        'preferences.json': describe(preferencesBytes),
      },
    }),
  );
  final archive = Archive()
    ..addFile(ArchiveFile.bytes('manifest.json', manifestBytes))
    ..addFile(ArchiveFile.bytes(databaseEntry, databaseBytes))
    ..addFile(ArchiveFile.bytes('preferences.json', preferencesBytes));
  await File(packagePath).writeAsBytes(ZipEncoder().encode(archive));
}

Future<String> _rewritePackageEntry(
  String sourcePath,
  String targetPath,
  String entryName,
  List<int> Function(List<int> bytes) transform,
) async {
  final decoded = ZipDecoder().decodeBytes(
    await File(sourcePath).readAsBytes(),
  );
  final rewritten = Archive();
  for (final entry in decoded) {
    final bytes = entry.readBytes()!;
    rewritten.addFile(
      ArchiveFile.bytes(
        entry.name,
        entry.name == entryName ? transform(bytes) : bytes,
      ),
    );
  }
  await File(targetPath).writeAsBytes(ZipEncoder().encode(rewritten));
  return targetPath;
}

Future<void> _expectPreferencesUnchanged() async {
  final preferences = await SharedPreferences.getInstance();
  expect(preferences.getString('locale_language_code'), 'de');
  expect(preferences.getString('theme_preference'), 'dark');
  expect(preferences.getInt('custom_theme_seed_color'), 0xff123456);
  expect(preferences.getString('mileage_unit'), 'mi');
  expect(preferences.getInt('default_vehicle_id'), 42);
  expect(preferences.getBool('notifications_enabled'), isTrue);
  expect(preferences.getInt('reminder_lead_time_days'), 14);
  expect(preferences.getString('due_reminder_threshold'), 'month');
  expect(preferences.getInt('due_reminder_item_count'), 5);
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
        onConfigure: DatabaseSchema.configure,
        onCreate: _createSchema,
        onUpgrade: DatabaseSchema.upgrade,
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
      onConfigure: DatabaseSchema.configure,
      onCreate: _createSchema,
      onUpgrade: DatabaseSchema.upgrade,
    ),
  );
  await _insertVehicle(database, name: vehicleName);
  await database.close();
}

Future<void> _createSchema(Database database, int version) async {
  await DatabaseSchema.create(database, version);
}

Future<void> _createLegacySchemaWithoutForeignKeys(
  Database database,
  int version,
) async {
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

final class _FailingBackupPreferences implements BackupPreferencesPort {
  const _FailingBackupPreferences();

  @override
  Future<Map<String, Object>> readBackupPreferences() async => const {};

  @override
  Future<void> replaceBackupPreferences(Map<String, Object> values) {
    throw StateError('Injected preference write failure');
  }
}
