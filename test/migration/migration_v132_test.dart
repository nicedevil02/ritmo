import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v132_zone_separation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MigrationV132ZoneSeparation Unit Tests (F-11, F-12, F-13)', () {
    test('Migration v132 adds hideOtherRealms, creates zone_budgets, zone_profiles, and updates zone_schedules', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE zones (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              color TEXT NOT NULL,
              icon TEXT NOT NULL,
              mode TEXT NOT NULL DEFAULT 'NORMAL',
              isDefault INTEGER NOT NULL DEFAULT 0,
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL
            );
          ''');

          await db.execute('''
            CREATE TABLE zone_schedules (
              id TEXT PRIMARY KEY,
              zoneId TEXT NOT NULL,
              daysOfWeek TEXT NOT NULL,
              startTime TEXT NOT NULL,
              endTime TEXT NOT NULL,
              createdAt INTEGER NOT NULL,
              FOREIGN KEY(zoneId) REFERENCES zones(id) ON DELETE CASCADE
            );
          ''');
        },
      );

      final migration = MigrationV132ZoneSeparation();
      await migration.up(db);

      // 1. Verify zones column hideOtherRealms
      final zoneCols = await db.rawQuery('PRAGMA table_info(zones)');
      final zoneColNames = zoneCols.map((c) => c['name'] as String).toList();
      expect(zoneColNames, contains('hideOtherRealms'));

      // 2. Verify zone_budgets table
      final budgetTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='zone_budgets'",
      );
      expect(budgetTables.length, 1);
      final budgetCols = await db.rawQuery('PRAGMA table_info(zone_budgets)');
      final budgetColNames = budgetCols.map((c) => c['name'] as String).toList();
      expect(budgetColNames, contains('zoneId'));
      expect(budgetColNames, contains('minMinutes'));
      expect(budgetColNames, contains('maxMinutes'));
      expect(budgetColNames, contains('period'));
      expect(budgetColNames, contains('updatedAt'));

      // 3. Verify zone_profiles table
      final profileTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='zone_profiles'",
      );
      expect(profileTables.length, 1);
      final profileCols = await db.rawQuery('PRAGMA table_info(zone_profiles)');
      final profileColNames = profileCols.map((c) => c['name'] as String).toList();
      expect(profileColNames, contains('id'));
      expect(profileColNames, contains('name'));
      expect(profileColNames, contains('isActive'));
      expect(profileColNames, contains('createdAt'));

      // 4. Verify zone_schedules columns
      final scheduleCols = await db.rawQuery('PRAGMA table_info(zone_schedules)');
      final scheduleColNames = scheduleCols.map((c) => c['name'] as String).toList();
      expect(scheduleColNames, contains('profileId'));
      expect(scheduleColNames, contains('isEnabled'));

      await db.close();
    });
  });
}
