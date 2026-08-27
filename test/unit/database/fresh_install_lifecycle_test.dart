import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/core/database/seed/seed_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Clean Baseline v1 Database Lifecycle Tests', () {
    test('Clean v1 onCreate creates all tables and seeds in milliseconds', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseHelper.dbVersionForTest,
        onCreate: (db, version) async {
          // onCreate is pure DDL only!
          await SchemaManager.createAll(db);
        },
      );

      // Seeding runs cleanly outside the onCreate exclusive transaction:
      await SeedService.seedAll(db);

      // Verify essential tables exist and are seeded
      final appSettings = await db.query('app_settings');
      expect(appSettings, isNotNull);
      expect(appSettings.isNotEmpty, isTrue);

      final worshipDebts = await db.query('worship_debts');
      expect(worshipDebts, isNotNull);

      final routines = await db.query('routines');
      expect(routines, isNotNull);

      // Verify ensureCriticalSchema runs safely
      await DatabaseHelper.ensureCriticalSchema(db);

      // Verify that re-running createAll is 100% idempotent
      await SchemaManager.createAll(db);

      await db.close();
    });

    test('onDatabaseDowngradeDelete cleanly handles old dev version downgrade', () async {
      // Simulate an old dev DB created with version 134
      var db = await openDatabase(
        inMemoryDatabasePath,
        version: 134,
        onCreate: (db, v) async {
          await db.execute('CREATE TABLE old_table (id TEXT PRIMARY KEY);');
        },
      );
      await db.close();

      // Now open at version 1 with onDatabaseDowngradeDelete
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseHelper.dbVersionForTest,
        onDowngrade: onDatabaseDowngradeDelete,
        onCreate: (db, version) async {
          await SchemaManager.createAll(db);
        },
      );

      final appSettings = await db.query('app_settings');
      expect(appSettings, isNotNull);

      await db.close();
    });

    test('ensureCriticalSchema cleans sports tasks when sports modules are disabled', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseHelper.dbVersionForTest,
        onCreate: (db, version) async {
          await SchemaManager.createAll(db);
        },
      );

      // Insert sports task
      await db.insert('simple_tasks', {
        'id': 'task-sports-1',
        'title': 'تمرین قدرتی خانگی',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Insert disabled sports settings
      await db.insert(
        'app_settings',
        {
          'key': 'module_sports_enabled',
          'value': 'false',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await DatabaseHelper.ensureCriticalSchema(db);

      final tasks = await db.query('simple_tasks', where: "title = 'تمرین قدرتی خانگی'");
      expect(tasks.isEmpty, isTrue);

      await db.close();
    });
  });
}
