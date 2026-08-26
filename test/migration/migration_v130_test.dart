import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v130_zone_sessions.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MigrationV130ZoneSessions Unit Tests (F-01, F-02)', () {
    test('Migration v130 creates zone_sessions table, indexes, and partial unique index', () async {
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

      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert('zones', {
        'id': 'z1',
        'name': 'کار',
        'color': '#3B82F6',
        'icon': '💼',
        'mode': 'NORMAL',
        'isDefault': 1,
        'createdAt': now,
        'updatedAt': now,
      });

      // Run Migration V130
      final migration = MigrationV130ZoneSessions();
      await migration.up(db);

      // Verify table creation
      final tableInfo = await db.rawQuery("PRAGMA table_info(zone_sessions);");
      final columnNames = tableInfo.map((row) => row['name'] as String).toSet();

      expect(columnNames.contains('id'), isTrue);
      expect(columnNames.contains('zoneId'), isTrue);
      expect(columnNames.contains('startedAt'), isTrue);
      expect(columnNames.contains('endedAt'), isTrue);
      expect(columnNames.contains('plannedEndAt'), isTrue);
      expect(columnNames.contains('source'), isTrue);
      expect(columnNames.contains('endReason'), isTrue);
      expect(columnNames.contains('createdAt'), isTrue);

      // Insert open session
      await db.insert('zone_sessions', {
        'id': 's1',
        'zoneId': 'z1',
        'startedAt': now,
        'endedAt': null,
        'plannedEndAt': now + 3600000,
        'source': 'SCHEDULE',
        'createdAt': now,
      });

      final openSessions = await db.query('zone_sessions', where: 'endedAt IS NULL');
      expect(openSessions.length, 1);
      expect(openSessions.first['zoneId'], 'z1');

      // Verify partial unique index prevents a second concurrent open session
      expect(
        () async => await db.insert('zone_sessions', {
          'id': 's2',
          'zoneId': 'z1',
          'startedAt': now + 1000,
          'endedAt': null, // Also open!
          'source': 'MANUAL',
          'createdAt': now + 1000,
        }),
        throwsA(isA<DatabaseException>()),
      );

      await db.close();
    });
  });
}
