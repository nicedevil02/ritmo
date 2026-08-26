import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v133_zone_rituals.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MigrationV133ZoneRituals Unit Tests (F-14)', () {
    test('Migration v133 adds ritualOnEnter and ritualOnExit columns to zones table', () async {
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
        },
      );

      final migration = MigrationV133ZoneRituals();
      await migration.up(db);

      // Verify columns added
      final zoneCols = await db.rawQuery('PRAGMA table_info(zones)');
      final zoneColNames = zoneCols.map((c) => c['name'] as String).toList();
      expect(zoneColNames, contains('ritualOnEnter'));
      expect(zoneColNames, contains('ritualOnExit'));

      await db.close();
    });
  });
}
