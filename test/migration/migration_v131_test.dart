import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v131_zone_triggers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MigrationV131ZoneTriggers Unit Tests (F-08)', () {
    test('Migration v131 creates zone_triggers table and indexes', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          // Precursor zones table
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

      final migration = MigrationV131ZoneTriggers();
      await migration.up(db);

      // Verify zone_triggers table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='zone_triggers'",
      );
      expect(tables.length, 1);

      // Verify columns
      final columns = await db.rawQuery('PRAGMA table_info(zone_triggers)');
      final colNames = columns.map((c) => c['name'] as String).toList();

      expect(colNames, contains('id'));
      expect(colNames, contains('zoneId'));
      expect(colNames, contains('kind'));
      expect(colNames, contains('value'));
      expect(colNames, contains('priority'));
      expect(colNames, contains('isEnabled'));
      expect(colNames, contains('createdAt'));
      expect(colNames, contains('updatedAt'));

      // Verify indexes
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='zone_triggers'",
      );
      final indexNames = indexes.map((i) => i['name'] as String).toList();
      expect(indexNames, contains('idx_zone_triggers_kind'));
      expect(indexNames, contains('idx_zone_triggers_zone'));

      await db.close();
    });
  });
}
