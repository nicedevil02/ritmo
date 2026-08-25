import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v127_session_metrics.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MigrationV127SessionMetrics Unit Tests (S4-T1)', () {
    test(
      'Migration v127 adds 7 session metric columns and index preserving existing 3 records',
      () async {
        final db = await openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onCreate: (db, version) async {
            // Setup table as in v126 (without new metrics columns)
            await db.execute('''
            CREATE TABLE movement_sessions (
              id            TEXT PRIMARY KEY,
              kindCode      TEXT NOT NULL,
              routineId     TEXT,
              occurrenceId  TEXT,
              prescriptionId TEXT,
              sessionMode   TEXT NOT NULL,
              status        TEXT NOT NULL,
              startedAt     INTEGER NOT NULL,
              endedAt       INTEGER,
              pausedMs      INTEGER NOT NULL DEFAULT 0,
              targetJson    TEXT,
              liveJson      TEXT,
              workoutLogId  TEXT,
              overallFeeling INTEGER,
              note          TEXT,
              createdAt     INTEGER NOT NULL,
              updatedAt     INTEGER NOT NULL
            );
          ''');
          },
        );

        // Insert 3 legacy records
        await db.insert('movement_sessions', {
          'id': 'sess_1',
          'kindCode': 'FOOTBALL',
          'sessionMode': 'MANUAL',
          'status': 'COMPLETED',
          'startedAt': 1700000000,
          'overallFeeling': 4,
          'note': 'Good match',
          'createdAt': 1700000000,
          'updatedAt': 1700003600,
        });

        await db.insert('movement_sessions', {
          'id': 'sess_2',
          'kindCode': 'HIKING',
          'sessionMode': 'FREE_RECORD',
          'status': 'COMPLETED',
          'startedAt': 1700100000,
          'overallFeeling': 5,
          'note': 'Tochal peak',
          'createdAt': 1700100000,
          'updatedAt': 1700114400,
        });

        await db.insert('movement_sessions', {
          'id': 'sess_3',
          'kindCode': 'BODYWEIGHT',
          'sessionMode': 'GUIDED',
          'status': 'COMPLETED',
          'startedAt': 1700200000,
          'overallFeeling': 3,
          'note': 'Core workout',
          'createdAt': 1700200000,
          'updatedAt': 1700202700,
        });

        // Run Migration v127
        final migration = MigrationV127SessionMetrics();
        expect(migration.version, equals(127));
        await migration.up(db);

        // Verify table info contains the 7 new columns
        final tableInfo = await db.rawQuery(
          'PRAGMA table_info(movement_sessions);',
        );
        final columnNames = tableInfo.map((c) => c['name'] as String).toSet();

        expect(columnNames, contains('distanceM'));
        expect(columnNames, contains('elevationGainM'));
        expect(columnNames, contains('laps'));
        expect(columnNames, contains('packWeightKg'));
        expect(columnNames, contains('rpe1To10'));
        expect(columnNames, contains('effortSource'));
        expect(columnNames, contains('routeId'));

        // Verify the 3 existing records are intact with original data
        final records = await db.query('movement_sessions', orderBy: 'id ASC');
        expect(records.length, equals(3));

        expect(records[0]['id'], equals('sess_1'));
        expect(records[0]['kindCode'], equals('FOOTBALL'));
        expect(records[0]['note'], equals('Good match'));
        expect(records[0]['distanceM'], isNull);

        expect(records[1]['id'], equals('sess_2'));
        expect(records[1]['kindCode'], equals('HIKING'));
        expect(records[1]['note'], equals('Tochal peak'));

        expect(records[2]['id'], equals('sess_3'));
        expect(records[2]['kindCode'], equals('BODYWEIGHT'));

        // Verify inserting new record with metrics
        await db.insert('movement_sessions', {
          'id': 'sess_4',
          'kindCode': 'HIKING',
          'sessionMode': 'FREE_RECORD',
          'status': 'COMPLETED',
          'startedAt': 1700300000,
          'overallFeeling': 5,
          'note': 'Mountaineering with backpack',
          'distanceM': 9400.0,
          'elevationGainM': 780.0,
          'laps': 0,
          'packWeightKg': 6.0,
          'rpe1To10': 7,
          'effortSource': 'user',
          'routeId': 101,
          'createdAt': 1700300000,
          'updatedAt': 1700318000,
        });

        final newRecord = await db.query(
          'movement_sessions',
          where: 'id = ?',
          whereArgs: ['sess_4'],
        );
        expect(newRecord.length, equals(1));
        expect(newRecord.first['distanceM'], equals(9400.0));
        expect(newRecord.first['elevationGainM'], equals(780.0));
        expect(newRecord.first['packWeightKg'], equals(6.0));
        expect(newRecord.first['rpe1To10'], equals(7));
        expect(newRecord.first['effortSource'], equals('user'));
        expect(newRecord.first['routeId'], equals(101));

        // Verify index exists
        final indexInfo = await db.rawQuery(
          "PRAGMA index_list('movement_sessions');",
        );
        final indexNames = indexInfo.map((i) => i['name'] as String).toSet();
        expect(indexNames, contains('idx_movement_sessions_kind_date'));

        await db.close();
      },
    );
  });
}
