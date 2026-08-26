import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/core/domain/realm/presets/realm_presets.dart';
import 'package:ritmo/core/repositories/realm_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Realm Presets & 1-Tap Template Creation (F-05)', () {
    test('1. Standard presets list contains all 6 canonical life realms', () {
      expect(RealmPreset.standardPresets.length, 6);

      final names = RealmPreset.standardPresets.map((p) => p.name).toList();
      expect(names, contains('کار و حرفه'));
      expect(names, contains('خانواده و خانه'));
      expect(names, contains('مطالعه و یادگیری'));
      expect(names, contains('ورزش و تندرستی'));
      expect(names, contains('عبادت و معنویت'));
      expect(names, contains('خواب و ریکاوری'));

      // Check modes
      final work = RealmPreset.standardPresets.firstWhere((p) => p.id == 'preset_work');
      expect(work.mode, RealmMode.focus);
      expect(work.icon, '💼');

      final family = RealmPreset.standardPresets.firstWhere((p) => p.id == 'preset_family');
      expect(family.mode, RealmMode.silent);
      expect(family.icon, '👨‍👩‍👧');

      final sleep = RealmPreset.standardPresets.firstWhere((p) => p.id == 'preset_sleep');
      expect(sleep.mode, RealmMode.silent);
      expect(sleep.startTime, '23:00');
      expect(sleep.endTime, '06:30');
    });

    test('2. createFromPreset atomically creates zone and schedule in database', () async {
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
              updatedAt INTEGER NOT NULL,
              FOREIGN KEY(zoneId) REFERENCES zones(id) ON DELETE CASCADE
            );
          ''');

          await db.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT,
              updatedAt INTEGER NOT NULL
            );
          ''');
        },
      );

      final repo = RealmRepository();
      final workPreset = RealmPreset.standardPresets.firstWhere((p) => p.id == 'preset_work');

      final zoneId = await repo.createFromPreset(workPreset, executor: db);
      expect(zoneId, startsWith('zone_work_'));

      // Verify zone record
      final zones = await db.query('zones', where: 'id = ?', whereArgs: [zoneId]);
      expect(zones.length, 1);
      expect(zones.first['name'], 'کار و حرفه');
      expect(zones.first['mode'], 'FOCUS');
      expect(zones.first['icon'], '💼');

      // Verify schedule record
      final schedules = await db.query('zone_schedules', where: 'zoneId = ?', whereArgs: [zoneId]);
      expect(schedules.length, 1);
      expect(schedules.first['startTime'], '08:30');
      expect(schedules.first['endTime'], '16:30');
      expect(schedules.first['daysOfWeek'], '6,7,1,2,3');

      await db.close();
    });
  });
}
