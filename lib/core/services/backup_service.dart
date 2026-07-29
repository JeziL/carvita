import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:carvita/application/ports/backup_preferences_port.dart';
import 'package:carvita/data/sources/local/database_helper.dart';
import 'package:carvita/data/sources/local/database_schema.dart';

abstract interface class BackupDatabaseConnection {
  Future<void> close();

  Future<Database> open();
}

abstract interface class BackupDatabaseController {
  Future<T> runExclusive<T>(
    Future<T> Function(BackupDatabaseConnection connection) operation,
  );
}

class BackupException implements Exception {
  const BackupException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class BackupSourceNotFoundException extends BackupException {
  BackupSourceNotFoundException(String sourcePath)
    : super('Database file not found: $sourcePath');
}

class InvalidBackupException extends BackupException {
  const InvalidBackupException(super.message, {super.cause});
}

class UnsupportedBackupFormatException extends InvalidBackupException {
  const UnsupportedBackupFormatException(super.message, {super.cause});
}

class BackupRestoreException extends BackupException {
  const BackupRestoreException(super.message, {super.cause});
}

abstract interface class BackupGateway {
  Future<String> createExportSnapshot({String applicationVersion = 'unknown'});

  Future<void> deleteExportSnapshot(String snapshotPath);

  Future<void> restoreDatabase(String selectedPath);
}

class BackupService implements BackupGateway {
  BackupService({
    BackupDatabaseController? databaseController,
    DatabaseFactory? sqliteFactory,
    Future<String> Function()? databaseDirectoryProvider,
    Future<Directory> Function()? temporaryDirectoryProvider,
    BackupPreferencesPort? preferences,
    DateTime Function()? clock,
  }) : _databaseController =
           databaseController ?? _DatabaseHelperBackupController(),
       _sqliteFactory = sqliteFactory ?? databaseFactory,
       _databaseDirectoryProvider =
           databaseDirectoryProvider ?? getDatabasesPath,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _preferences = preferences ?? const _EmptyBackupPreferences(),
       _clock = clock ?? DateTime.now;

  static const int backupFormatVersion = 1;
  static const int backupPreferencesVersion = 1;
  static const int supportedSchemaVersion = DatabaseHelper.schemaVersion;
  static const Set<int> supportedRestoreSchemaVersions =
      DatabaseSchema.restorableVersions;
  static const String _manifestPath = 'manifest.json';
  static const String _databaseEntryPath = 'database/${DatabaseHelper.dbName}';
  static const String _preferencesEntryPath = 'preferences.json';

  static const Map<int, Map<String, Set<String>>> _requiredSchemas = {
    DatabaseSchema.legacyVersion: {
      'vehicles': {
        'id',
        'name',
        'mileage',
        'mileage_last_updated',
        'bought_date',
        'image',
        'model',
        'plate_number',
        'vin',
        'engine_number',
      },
      'maintenance_plan_items': {
        'id',
        'vehicleId',
        'itemName',
        'intervalTimeMonths',
        'intervalMileage',
        'firstIntervalTimeMonths',
        'firstIntervalMileage',
        'notes',
        'isActive',
      },
      'service_log_entries': {
        'id',
        'vehicleId',
        'serviceDate',
        'mileageAtService',
        'cost',
        'notes',
      },
      'service_log_performed_items': {
        'id',
        'serviceLogId',
        'maintenancePlanItemId',
        'customItemName',
      },
    },
    DatabaseSchema.currentVersion: {
      'vehicles': {
        'id',
        'name',
        'mileage',
        'mileage_last_updated',
        'bought_date',
        'image',
        'model',
        'plate_number',
        'vin',
        'engine_number',
      },
      'maintenance_plan_items': {
        'id',
        'vehicleId',
        'itemName',
        'intervalTimeMonths',
        'intervalMileage',
        'firstIntervalTimeMonths',
        'firstIntervalMileage',
        'notes',
        'isActive',
        'baselineDate',
        'baselineMileage',
      },
      'service_log_entries': {
        'id',
        'vehicleId',
        'serviceDate',
        'mileageAtService',
        'cost',
        'notes',
      },
      'service_log_performed_items': {
        'id',
        'serviceLogId',
        'maintenancePlanItemId',
        'customItemName',
      },
    },
  };

  static const Set<String> _allowedPlatformTables = {'android_metadata'};

  static const List<int> _sqliteHeader = [
    0x53,
    0x51,
    0x4c,
    0x69,
    0x74,
    0x65,
    0x20,
    0x66,
    0x6f,
    0x72,
    0x6d,
    0x61,
    0x74,
    0x20,
    0x33,
    0x00,
  ];

  final BackupDatabaseController _databaseController;
  final DatabaseFactory _sqliteFactory;
  final Future<String> Function() _databaseDirectoryProvider;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final BackupPreferencesPort _preferences;
  final DateTime Function() _clock;

  Future<void> _operationTail = Future<void>.value();

  @override
  Future<String> createExportSnapshot({String applicationVersion = 'unknown'}) {
    return _serialize(() async {
      final databaseSnapshotPath = await _createDatabaseSnapshot();
      try {
        return await _createBackupPackage(
          databaseSnapshotPath,
          applicationVersion: applicationVersion,
        );
      } finally {
        await _bestEffortDelete(File(databaseSnapshotPath));
      }
    });
  }

  Future<String> _createDatabaseSnapshot() async {
    final databaseDirectory = await _databaseDirectoryProvider();
    final sourcePath = path.join(databaseDirectory, DatabaseHelper.dbName);

    return _databaseController.runExclusive((connection) async {
      String? snapshotPath;
      Object? exportFailure;
      StackTrace? exportStackTrace;

      try {
        await connection.close();

        final sourceFile = File(sourcePath);
        if (!await sourceFile.exists()) {
          throw BackupSourceNotFoundException(sourcePath);
        }

        final temporaryDirectory = await _temporaryDirectoryProvider();
        await temporaryDirectory.create(recursive: true);
        snapshotPath = await _uniquePath(
          temporaryDirectory.path,
          '.carvita_database_snapshot_${_formatTimestamp(_clock())}',
          '.db',
        );
        await sourceFile.copy(snapshotPath);
        await _validateDatabaseFile(snapshotPath);
      } catch (error, stackTrace) {
        exportFailure = error;
        exportStackTrace = stackTrace;
      }

      Object? reopenFailure;
      StackTrace? reopenStackTrace;
      try {
        await connection.open();
      } catch (error, stackTrace) {
        reopenFailure = error;
        reopenStackTrace = stackTrace;
      }

      if (reopenFailure != null) {
        if (snapshotPath != null) {
          await _bestEffortDelete(File(snapshotPath));
        }
        Error.throwWithStackTrace(
          BackupException(
            exportFailure == null
                ? 'The database snapshot was created, but the app database '
                      'could not be reopened.'
                : 'Database export failed and the app database could not be '
                      'reopened.',
            cause: reopenFailure,
          ),
          reopenStackTrace!,
        );
      }

      if (exportFailure != null) {
        if (snapshotPath != null) {
          await _bestEffortDelete(File(snapshotPath));
        }
        Error.throwWithStackTrace(exportFailure, exportStackTrace!);
      }

      return snapshotPath!;
    });
  }

  Future<String> _createBackupPackage(
    String databaseSnapshotPath, {
    required String applicationVersion,
  }) async {
    final databaseBytes = await File(databaseSnapshotPath).readAsBytes();
    final preferenceValues = await _preferences.readBackupPreferences();
    final preferencesBytes = utf8.encode(
      jsonEncode({
        'version': backupPreferencesVersion,
        'values': preferenceValues,
      }),
    );
    final createdAt = _clock().toUtc();
    final manifestBytes = utf8.encode(
      jsonEncode({
        'formatVersion': backupFormatVersion,
        'databaseSchemaVersion': supportedSchemaVersion,
        'applicationVersion': applicationVersion,
        'createdAt': createdAt.toIso8601String(),
        'contents': {
          _databaseEntryPath: _contentDescription(databaseBytes),
          _preferencesEntryPath: _contentDescription(preferencesBytes),
        },
      }),
    );

    final archive = Archive()
      ..addFile(ArchiveFile.bytes(_manifestPath, manifestBytes))
      ..addFile(ArchiveFile.bytes(_databaseEntryPath, databaseBytes))
      ..addFile(ArchiveFile.bytes(_preferencesEntryPath, preferencesBytes));
    final encoded = ZipEncoder().encode(archive);

    final temporaryDirectory = await _temporaryDirectoryProvider();
    await temporaryDirectory.create(recursive: true);
    final packagePath = await _uniquePath(
      temporaryDirectory.path,
      'carvita_backup_${_formatTimestamp(createdAt.toLocal())}',
      '.cvbackup',
    );
    await File(packagePath).writeAsBytes(encoded, flush: true);
    await _readBackupPackage(packagePath);
    return packagePath;
  }

  Map<String, Object> _contentDescription(List<int> bytes) {
    return {'size': bytes.length, 'sha256': sha256.convert(bytes).toString()};
  }

  @override
  Future<void> deleteExportSnapshot(String snapshotPath) async {
    try {
      final temporaryDirectory = await _temporaryDirectoryProvider();
      final normalizedTemporaryPath = path.normalize(
        path.absolute(temporaryDirectory.path),
      );
      final normalizedSnapshotPath = path.normalize(
        path.absolute(snapshotPath),
      );
      final snapshotName = path.basename(normalizedSnapshotPath);
      final extension = path.extension(snapshotName).toLowerCase();

      if (!path.isWithin(normalizedTemporaryPath, normalizedSnapshotPath) ||
          !snapshotName.startsWith('carvita_backup_') ||
          (extension != '.cvbackup' && extension != '.db')) {
        return;
      }

      await _bestEffortDelete(File(normalizedSnapshotPath));
    } catch (_) {
      // Cleanup must never obscure the export/share result.
    }
  }

  @override
  Future<void> restoreDatabase(String sourcePath) {
    return _serialize(() async {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw BackupSourceNotFoundException(sourcePath);
      }
      final package = await _isSqliteFile(sourceFile)
          ? null
          : await _readBackupPackage(sourcePath);

      final databaseDirectory = await _databaseDirectoryProvider();
      final databaseDirectoryHandle = Directory(databaseDirectory);
      await databaseDirectoryHandle.create(recursive: true);
      final liveDatabasePath = path.join(
        databaseDirectory,
        DatabaseHelper.dbName,
      );
      final stagingPath = await _uniquePath(
        databaseDirectory,
        '.${DatabaseHelper.dbName}.restore-staging',
        '.db',
      );
      final stagingFile = package == null
          ? await sourceFile.copy(stagingPath)
          : await File(
              stagingPath,
            ).writeAsBytes(package.databaseBytes, flush: true);

      try {
        await _validateDatabaseFile(
          stagingPath,
          acceptedSchemaVersions: package == null
              ? supportedRestoreSchemaVersions
              : {package.databaseSchemaVersion},
        );
        await _databaseController.runExclusive((connection) async {
          Object? restoreFailure;
          StackTrace? restoreStackTrace;

          try {
            await _replaceDatabase(
              connection: connection,
              liveDatabasePath: liveDatabasePath,
              stagingFile: stagingFile,
              afterInstall: package == null
                  ? null
                  : () => _preferences.replaceBackupPreferences(
                      package.preferences,
                    ),
            );
          } catch (error, stackTrace) {
            restoreFailure = error;
            restoreStackTrace = stackTrace;
          }

          Object? reopenFailure;
          StackTrace? reopenStackTrace;
          try {
            final database = await connection.open();
            await _validateOpenDatabase(database);
          } catch (error, stackTrace) {
            reopenFailure = error;
            reopenStackTrace = stackTrace;
          }

          if (restoreFailure != null) {
            if (reopenFailure != null) {
              Error.throwWithStackTrace(
                BackupRestoreException(
                  'Database restore failed, and the app database could not be '
                  'reopened after rollback.',
                  cause: reopenFailure,
                ),
                reopenStackTrace!,
              );
            }
            Error.throwWithStackTrace(restoreFailure, restoreStackTrace!);
          }

          if (reopenFailure != null) {
            Error.throwWithStackTrace(
              BackupRestoreException(
                'The database was restored, but the app database could not be '
                'reopened.',
                cause: reopenFailure,
              ),
              reopenStackTrace!,
            );
          }
        });
      } finally {
        await _bestEffortDelete(File(stagingPath));
      }
    });
  }

  Future<void> _replaceDatabase({
    required BackupDatabaseConnection connection,
    required String liveDatabasePath,
    required File stagingFile,
    Future<void> Function()? afterInstall,
  }) async {
    final liveDatabaseFile = File(liveDatabasePath);
    final rollbackPath = await _uniquePath(
      path.dirname(liveDatabasePath),
      '.${DatabaseHelper.dbName}.rollback',
      '.db',
    );
    final rollbackFile = File(rollbackPath);
    var rollbackCreated = false;
    var candidateInstalled = false;

    try {
      await connection.close();
      await _deleteDatabaseSidecars(liveDatabasePath);

      if (await liveDatabaseFile.exists()) {
        await liveDatabaseFile.copy(rollbackPath);
        rollbackCreated = true;
      }

      // Staging lives in the same directory, so this is an atomic rename on
      // Android's supported filesystems. The rollback copy remains untouched.
      await stagingFile.rename(liveDatabasePath);
      candidateInstalled = true;

      final restoredDatabase = await connection.open();
      await _validateOpenDatabase(restoredDatabase);
      await afterInstall?.call();
    } catch (error, stackTrace) {
      try {
        await _rollbackDatabase(
          connection: connection,
          liveDatabasePath: liveDatabasePath,
          rollbackFile: rollbackFile,
          rollbackCreated: rollbackCreated,
          candidateInstalled: candidateInstalled,
        );
      } catch (rollbackError) {
        Error.throwWithStackTrace(
          BackupRestoreException(
            'Database restore failed and the previous database could not be '
            'recovered automatically.',
            cause: rollbackError,
          ),
          stackTrace,
        );
      }

      Error.throwWithStackTrace(
        BackupRestoreException(
          rollbackCreated
              ? 'The selected backup could not be restored. The previous '
                    'database was restored.'
              : 'The selected backup could not be restored.',
          cause: error,
        ),
        stackTrace,
      );
    }

    if (rollbackCreated) {
      await _bestEffortDelete(rollbackFile);
    }
  }

  Future<bool> _isSqliteFile(File file) async {
    if (await file.length() < _sqliteHeader.length) return false;
    final reader = await file.open();
    try {
      return _bytesEqual(
        await reader.read(_sqliteHeader.length),
        _sqliteHeader,
      );
    } finally {
      await reader.close();
    }
  }

  Future<_BackupPackage> _readBackupPackage(String packagePath) async {
    try {
      final archive = ZipDecoder().decodeBytes(
        await File(packagePath).readAsBytes(),
        verify: true,
      );
      final files = <String, ArchiveFile>{};
      for (final entry in archive) {
        if (!entry.isFile || entry.isSymbolicLink) {
          throw const InvalidBackupException(
            'The backup package contains unsupported entries.',
          );
        }
        if (files.containsKey(entry.name)) {
          throw const InvalidBackupException(
            'The backup package contains duplicate entries.',
          );
        }
        files[entry.name] = entry;
      }
      const expectedPaths = {
        _manifestPath,
        _databaseEntryPath,
        _preferencesEntryPath,
      };
      if (!_setsEqual(files.keys.toSet(), expectedPaths)) {
        throw const InvalidBackupException(
          'The backup package has an incompatible content list.',
        );
      }

      final manifestBytes = files[_manifestPath]!.readBytes();
      final databaseBytes = files[_databaseEntryPath]!.readBytes();
      final preferencesBytes = files[_preferencesEntryPath]!.readBytes();
      if (manifestBytes == null ||
          databaseBytes == null ||
          preferencesBytes == null) {
        throw const InvalidBackupException(
          'The backup package contains unreadable content.',
        );
      }

      final manifest = _decodeJsonObject(manifestBytes, 'manifest');
      final formatVersion = manifest['formatVersion'];
      if (formatVersion is! int || formatVersion != backupFormatVersion) {
        throw UnsupportedBackupFormatException(
          'Unsupported backup format version: ${formatVersion ?? 'unknown'}.',
        );
      }
      final databaseSchemaVersion = manifest['databaseSchemaVersion'];
      if (databaseSchemaVersion is! int ||
          !supportedRestoreSchemaVersions.contains(databaseSchemaVersion)) {
        throw UnsupportedBackupFormatException(
          'Unsupported database schema version in backup package: '
          '${databaseSchemaVersion ?? 'unknown'}.',
        );
      }
      final applicationVersion = manifest['applicationVersion'];
      if (applicationVersion is! String || applicationVersion.isEmpty) {
        throw const InvalidBackupException(
          'The backup package has no application version.',
        );
      }
      final createdAt = manifest['createdAt'];
      if (createdAt is! String || DateTime.tryParse(createdAt) == null) {
        throw const InvalidBackupException(
          'The backup package has an invalid creation time.',
        );
      }
      final contents = manifest['contents'];
      if (contents is! Map<String, dynamic> ||
          !_setsEqual(contents.keys.toSet(), {
            _databaseEntryPath,
            _preferencesEntryPath,
          })) {
        throw const InvalidBackupException(
          'The backup manifest has an incompatible content list.',
        );
      }
      _validateContentDescription(
        contents[_databaseEntryPath],
        databaseBytes,
        _databaseEntryPath,
      );
      _validateContentDescription(
        contents[_preferencesEntryPath],
        preferencesBytes,
        _preferencesEntryPath,
      );

      final preferencesDocument = _decodeJsonObject(
        preferencesBytes,
        'preferences',
      );
      if (preferencesDocument['version'] != backupPreferencesVersion) {
        throw UnsupportedBackupFormatException(
          'Unsupported backup preferences version: '
          '${preferencesDocument['version'] ?? 'unknown'}.',
        );
      }
      final rawValues = preferencesDocument['values'];
      if (rawValues is! Map<String, dynamic>) {
        throw const InvalidBackupException(
          'The backup preferences are invalid.',
        );
      }
      final preferences = validateBackupPreferenceValues(rawValues);
      return _BackupPackage(
        databaseBytes: databaseBytes,
        databaseSchemaVersion: databaseSchemaVersion,
        preferences: preferences,
      );
    } on BackupException {
      rethrow;
    } catch (error) {
      throw InvalidBackupException(
        'The selected file is not a valid CarVita backup package.',
        cause: error,
      );
    }
  }

  Map<String, dynamic> _decodeJsonObject(List<int> bytes, String label) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw InvalidBackupException('The backup $label is invalid.');
    }
    return decoded;
  }

  void _validateContentDescription(
    Object? rawDescription,
    List<int> bytes,
    String entryPath,
  ) {
    if (rawDescription is! Map<String, dynamic> ||
        rawDescription['size'] is! int ||
        rawDescription['sha256'] is! String) {
      throw InvalidBackupException(
        'The backup checksum metadata for $entryPath is invalid.',
      );
    }
    if (rawDescription['size'] != bytes.length ||
        rawDescription['sha256'] != sha256.convert(bytes).toString()) {
      throw InvalidBackupException(
        'The backup content checksum for $entryPath does not match.',
      );
    }
  }

  Future<void> _rollbackDatabase({
    required BackupDatabaseConnection connection,
    required String liveDatabasePath,
    required File rollbackFile,
    required bool rollbackCreated,
    required bool candidateInstalled,
  }) async {
    await connection.close();
    await _deleteDatabaseSidecars(liveDatabasePath);

    final liveDatabaseFile = File(liveDatabasePath);
    if (candidateInstalled && await liveDatabaseFile.exists()) {
      await liveDatabaseFile.delete();
    }

    if (rollbackCreated) {
      if (await liveDatabaseFile.exists()) {
        await liveDatabaseFile.delete();
      }
      await rollbackFile.rename(liveDatabasePath);
    }

    final recoveredDatabase = await connection.open();
    await _validateOpenDatabase(recoveredDatabase);
  }

  Future<int> _validateDatabaseFile(
    String databasePath, {
    Set<int> acceptedSchemaVersions = const {supportedSchemaVersion},
  }) async {
    final databaseFile = File(databasePath);
    if (!await databaseFile.exists()) {
      throw BackupSourceNotFoundException(databasePath);
    }
    if (await databaseFile.length() < 100) {
      throw const InvalidBackupException(
        'The selected file is not a valid CarVita database.',
      );
    }

    final reader = await databaseFile.open();
    late List<int> header;
    try {
      header = await reader.read(_sqliteHeader.length);
    } finally {
      await reader.close();
    }
    if (!_bytesEqual(header, _sqliteHeader)) {
      throw const InvalidBackupException(
        'The selected file is not a SQLite database.',
      );
    }

    Database? validationDatabase;
    try {
      validationDatabase = await _sqliteFactory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          readOnly: true,
          singleInstance: false,
          onConfigure: DatabaseSchema.configure,
        ),
      );
      return await _validateOpenDatabase(
        validationDatabase,
        acceptedSchemaVersions: acceptedSchemaVersions,
      );
    } on InvalidBackupException {
      rethrow;
    } catch (error) {
      throw InvalidBackupException(
        'The selected database could not be validated.',
        cause: error,
      );
    } finally {
      if (validationDatabase != null && validationDatabase.isOpen) {
        await validationDatabase.close();
      }
    }
  }

  Future<int> _validateOpenDatabase(
    Database database, {
    Set<int> acceptedSchemaVersions = const {supportedSchemaVersion},
  }) async {
    final foreignKeyRows = await database.rawQuery('PRAGMA foreign_keys');
    if (foreignKeyRows.isEmpty || foreignKeyRows.single.values.single != 1) {
      throw const InvalidBackupException(
        'SQLite foreign key enforcement is not enabled.',
      );
    }

    final integrityRows = await database.rawQuery('PRAGMA integrity_check');
    final integrityValues = integrityRows
        .expand((row) => row.values)
        .map((value) => value.toString().toLowerCase())
        .toList(growable: false);
    if (integrityValues.length != 1 || integrityValues.single != 'ok') {
      throw const InvalidBackupException(
        'The selected database failed its integrity check.',
      );
    }

    final versionRows = await database.rawQuery('PRAGMA user_version');
    final schemaVersion = versionRows.isEmpty
        ? null
        : versionRows.first.values.first as int?;
    if (schemaVersion == null ||
        !acceptedSchemaVersions.contains(schemaVersion)) {
      throw InvalidBackupException(
        'Unsupported database schema version: '
        '${schemaVersion ?? 'unknown'}.',
      );
    }

    final requiredSchema = _requiredSchemas[schemaVersion];
    if (requiredSchema == null) {
      throw InvalidBackupException(
        'Unsupported database schema version: $schemaVersion.',
      );
    }

    final schemaRows = await database.rawQuery(
      "SELECT type, name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",
    );
    final tableNames = schemaRows
        .where((row) => row['type'] == 'table')
        .map((row) => row['name'])
        .whereType<String>()
        .toSet();
    final applicationTableNames = tableNames.difference(_allowedPlatformTables);
    if (!_setsEqual(applicationTableNames, requiredSchema.keys.toSet())) {
      throw const InvalidBackupException(
        'The selected database contains an incompatible table set.',
      );
    }
    if (schemaRows.any(
      (row) => row['type'] == 'trigger' || row['type'] == 'view',
    )) {
      throw const InvalidBackupException(
        'The selected database contains unsupported triggers or views.',
      );
    }

    for (final schemaEntry in requiredSchema.entries) {
      final columnRows = await database.rawQuery(
        'PRAGMA table_info("${schemaEntry.key}")',
      );
      final columnNames = columnRows
          .map((row) => row['name'])
          .whereType<String>()
          .toSet();
      if (!_setsEqual(columnNames, schemaEntry.value)) {
        throw InvalidBackupException(
          'The selected database has an incompatible ${schemaEntry.key} '
          'table.',
        );
      }
    }

    final consistency = await DatabaseSchema.audit(database);
    if (consistency.hasBlockingSchemaOrValueErrors) {
      throw const InvalidBackupException(
        'The selected database has incompatible constraints or values.',
      );
    }
    if (schemaVersion == DatabaseSchema.currentVersion) {
      if (consistency.hasRelationshipIssues ||
          (await database.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
        throw const InvalidBackupException(
          'The selected database has inconsistent relationships.',
        );
      }
    }
    return schemaVersion;
  }

  Future<void> _deleteDatabaseSidecars(String databasePath) async {
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      final sidecar = File('$databasePath$suffix');
      if (await sidecar.exists()) {
        await sidecar.delete();
      }
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final previousOperation = _operationTail;
    final operationFinished = Completer<void>();
    _operationTail = operationFinished.future;

    return (() async {
      try {
        await previousOperation;
      } catch (_) {
        // A failed operation must not prevent a later user-requested operation.
      }

      try {
        return await operation();
      } finally {
        operationFinished.complete();
      }
    })();
  }

  Future<String> _uniquePath(
    String directory,
    String fileNamePrefix,
    String extension,
  ) async {
    var suffix = 0;
    while (true) {
      final candidateName = suffix == 0
          ? '$fileNamePrefix$extension'
          : '${fileNamePrefix}_$suffix$extension';
      final candidatePath = path.join(directory, candidateName);
      if (!await File(candidatePath).exists() &&
          !await Directory(candidatePath).exists()) {
        return candidatePath;
      }
      suffix++;
    }
  }

  Future<void> _bestEffortDelete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // A stale temporary/rollback file is safer than risking the live database.
    }
  }

  bool _bytesEqual(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  bool _setsEqual(Set<String> first, Set<String> second) {
    return first.length == second.length && first.containsAll(second);
  }

  String _formatTimestamp(DateTime timestamp) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    String threeDigits(int value) => value.toString().padLeft(3, '0');

    return '${timestamp.year.toString().padLeft(4, '0')}'
        '${twoDigits(timestamp.month)}'
        '${twoDigits(timestamp.day)}_'
        '${twoDigits(timestamp.hour)}'
        '${twoDigits(timestamp.minute)}'
        '${twoDigits(timestamp.second)}_'
        '${threeDigits(timestamp.millisecond)}';
  }
}

class _DatabaseHelperBackupController implements BackupDatabaseController {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  @override
  Future<T> runExclusive<T>(
    Future<T> Function(BackupDatabaseConnection connection) operation,
  ) {
    return _databaseHelper.runExclusiveMaintenance(
      (connection) => operation(_DatabaseHelperBackupConnection(connection)),
    );
  }
}

class _DatabaseHelperBackupConnection implements BackupDatabaseConnection {
  const _DatabaseHelperBackupConnection(this._connection);

  final DatabaseMaintenanceConnection _connection;

  @override
  Future<void> close() => _connection.close();

  @override
  Future<Database> open() => _connection.open();
}

final class _BackupPackage {
  const _BackupPackage({
    required this.databaseBytes,
    required this.databaseSchemaVersion,
    required this.preferences,
  });

  final Uint8List databaseBytes;
  final int databaseSchemaVersion;
  final Map<String, Object> preferences;
}

final class _EmptyBackupPreferences implements BackupPreferencesPort {
  const _EmptyBackupPreferences();

  @override
  Future<Map<String, Object>> readBackupPreferences() async => const {};

  @override
  Future<void> replaceBackupPreferences(Map<String, Object> values) async {}
}
