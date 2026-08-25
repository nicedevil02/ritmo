import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/migration/migration_runner.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('M1-M7 Migrations & Schema Verification', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await SupplementarySportsTables.create(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Fresh install creates all unified sports tables and indexes', () async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND (name LIKE 'ss_%' OR name LIKE 'movement_%')",
      );
      final tableNames = tables.map((t) => t['name'] as String).toList();

      expect(tableNames, contains('ss_session_prescription'));
      expect(tableNames, contains('ss_user_profile'));
      expect(tableNames, contains('ss_exercise'));
      expect(tableNames, contains('ss_session_set_log'));
      expect(tableNames, contains('movement_sessions'));
      expect(tableNames, contains('movement_session_events'));
      expect(tableNames, contains('movement_pr'));
      expect(tableNames, contains('movement_budget'));
      expect(tableNames, contains('movement_slot_overrides'));
    });

    test('M1: ss_session_prescription has unified columns', () async {
      final columnsInfo = await db.rawQuery("PRAGMA table_info('ss_session_prescription')");
      final colNames = columnsInfo.map((c) => c['name'] as String).toList();

      expect(colNames, contains('kindCode'));
      expect(colNames, contains('routineId'));
      expect(colNames, contains('plannedTime'));
      expect(colNames, contains('sourceRef'));
    });

    test('M3, M4, M5: migrateToUnifiedSchema mirrors sessions, sets, and PRs', () async {
      // 1. Insert mock legacy data
      await db.insert('ss_workout_session_log', {
        'id': 'legacy_sess_1',
        'startedAt': 100000,
        'finishedAt': 102000,
        'durationSeconds': 2000,
        'overallFeeling': 'good',
      });

      await db.insert('ss_workout_set_log', {
        'id': 'legacy_set_1',
        'session_id': 'legacy_sess_1',
        'exercise_id': 'push_up',
        'set_index': 1,
        'weight': 0.0,
        'reps': 15,
        'rir': 2,
      });

      await db.insert('ss_exercise_pr', {
        'id': 'legacy_pr_1',
        'exerciseId': 'push_up',
        'prType': 'maxReps',
        'value': 25.0,
        'sessionId': 'legacy_sess_1',
        'achievedAt': 100000,
      });

      // 2. Run M1-M7 migrations
      await SupplementarySportsTables.migrateToUnifiedSchema(db);

      // 3. Verify M3: Mirrored to movement_sessions
      final sessions = await db.query(
        'movement_sessions',
        where: 'id = ?',
        whereArgs: ['legacy_sess_1'],
      );
      expect(sessions.length, equals(1));
      expect(sessions.first['workoutLogId'], equals('legacy_sess_1'));
      expect(sessions.first['status'], equals('COMPLETED'));

      // 4. Verify M4: Mirrored to ss_session_set_log
      final setLogs = await db.query(
        'ss_session_set_log',
        where: 'sessionId = ?',
        whereArgs: ['legacy_sess_1'],
      );
      expect(setLogs.length, equals(1));
      expect(setLogs.first['exerciseId'], equals('push_up'));
      expect(setLogs.first['reps'], equals(15));

      // 5. Verify M5: Mirrored to movement_pr with EXERCISE: prefix
      final prs = await db.query(
        'movement_pr',
        where: 'kind = ?',
        whereArgs: ['EXERCISE:push_up'],
      );
      expect(prs.length, equals(1));
      expect(prs.first['value'], equals(25.0));
      expect(prs.first['prType'], equals('maxReps'));
    });

    test('MigrationRunner applies MigrationV121SportsUnification successfully', () async {
      final migrationDb = await databaseFactory.openDatabase(inMemoryDatabasePath);
      // Run from v120 to v121
      await MigrationRunner.run(migrationDb, 120, 121);

      final tables = await migrationDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='movement_sessions'",
      );
      expect(tables.isNotEmpty, isTrue);
      await migrationDb.close();
    });
  });
}
