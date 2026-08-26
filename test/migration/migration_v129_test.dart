import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v129_realm_stabilization.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MigrationV129RealmStabilization Unit Tests', () {
    test('Migration v129 cleans orphan keys, seeds override keys, normalizes modes, and enforces default unique index', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT,
              updatedAt INTEGER NOT NULL
            );
          ''');

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

      final now = DateTime.now().millisecondsSinceEpoch;

      // 1. Insert orphan keys
      await db.insert('app_settings', {'key': 'active_zone_id', 'value': 'old_zone', 'updatedAt': now});
      await db.insert('app_settings', {'key': 'active_zone_mode', 'value': 'WORK', 'updatedAt': now});
      await db.insert('app_settings', {'key': 'theme_mode', 'value': 'dark', 'updatedAt': now});

      // 2. Insert zones with legacy/invalid modes and duplicate isDefault
      await db.insert('zones', {
        'id': 'z1',
        'name': 'خانواده',
        'color': '#10B981',
        'icon': '👨‍👩‍👧',
        'mode': 'MUTE',
        'isDefault': 1,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      await db.insert('zones', {
        'id': 'z2',
        'name': 'کار',
        'color': '#3B82F6',
        'icon': '💼',
        'mode': 'WORK', // invalid mode!
        'isDefault': 1, // duplicate default!
        'createdAt': 2000,
        'updatedAt': 2000,
      });

      // Run Migration V129
      final migration = MigrationV129RealmStabilization();
      await migration.up(db);

      // Verify 1: Orphan keys removed, other keys preserved
      final settings = {
        for (final row in await db.query('app_settings'))
          row['key']! as String: row['value']! as String,
      };

      expect(settings.containsKey('active_zone_id'), isFalse);
      expect(settings.containsKey('active_zone_mode'), isFalse);
      expect(settings['theme_mode'], 'dark');
      expect(settings['realm_override_started_ms'], '0');
      expect(settings['realm_quick_override_minutes'], '50');

      // Verify 2: Modes normalized
      final z1 = (await db.query('zones', where: 'id = ?', whereArgs: ['z1'])).first;
      expect(z1['mode'], 'SILENT'); // MUTE -> SILENT

      final z2 = (await db.query('zones', where: 'id = ?', whereArgs: ['z2'])).first;
      expect(z2['mode'], 'NORMAL'); // WORK -> NORMAL

      // Verify 3: Only the oldest default zone remained default
      final defaults = await db.query('zones', where: 'isDefault = 1');
      expect(defaults.length, 1);
      expect(defaults.first['id'], 'z1');

      await db.close();
    });
  });
}
