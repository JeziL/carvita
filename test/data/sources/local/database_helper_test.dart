import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'package:carvita/data/sources/local/database_helper.dart';

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
}
