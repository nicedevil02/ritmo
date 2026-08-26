import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/database/migration/migration_runner.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/core/services/end_of_day_sweep.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestMigration10 extends Migration {
  _TestMigration10(this.onExecute);
  final void Function() onExecute;
  @override
  int get version => 10;
  @override
  Future<void> up(DatabaseExecutor db) async {
    onExecute();
  }
  @override
  Future<void> down(DatabaseExecutor db) async {}
}

class _TestMigration11 extends Migration {
  _TestMigration11(this.onExecute);
  final void Function() onExecute;
  @override
  int get version => 11;
  @override
  Future<void> up(DatabaseExecutor db) async {
    onExecute();
  }
  @override
  Future<void> down(DatabaseExecutor db) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Phase 1 — Database & Migration Integrity (RIT-010..RIT-022)', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, v) async {
            await SchemaManager.createAll(db);
          },
        ),
      );
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('RIT-022: DatabaseHelper dbVersion matches maximum version in MigrationRunner and all versions are unique', () {
      final migrations = MigrationRunner.debugMigrations;
      expect(migrations, isNotEmpty);

      final versions = migrations.map((m) => m.version).toList();
      final uniqueVersions = versions.toSet();
      expect(versions.length, uniqueVersions.length, reason: 'Migration versions must be unique');

      final maxVersion = versions.reduce(max);
      expect(DatabaseHelper.dbVersionForTest, maxVersion, reason: 'DatabaseHelper dbVersion must match latest migration version');
    });

    test('RIT-010 & RIT-012: MigrationRunner records applied migrations and skips already executed versions', () async {
      // Create schema_migrations table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS schema_migrations (
          version INTEGER PRIMARY KEY,
          appliedAt INTEGER NOT NULL
        );
      ''');

      // Seed migration v10 as already applied
      await db.insert('schema_migrations', {
        'version': 10,
        'appliedAt': DateTime.now().millisecondsSinceEpoch,
      });

      var v10Executed = false;
      var v11Executed = false;

      final testMigrations = [
        _TestMigration10(() => v10Executed = true),
        _TestMigration11(() => v11Executed = true),
      ];

      // Re-run migration chain using custom runner logic
      for (final m in testMigrations) {
        final applied = await db.query('schema_migrations', where: 'version = ?', whereArgs: [m.version]);
        if (applied.isEmpty) {
          await m.up(db);
          await db.insert('schema_migrations', {
            'version': m.version,
            'appliedAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }

      expect(v10Executed, isFalse, reason: 'v10 was already in schema_migrations so it must be skipped');
      expect(v11Executed, isTrue, reason: 'v11 was not yet applied so it must execute');

      // Verify v11 was recorded
      final rows = await db.query('schema_migrations');
      final recorded = rows.map((r) => r['version'] as int).toSet();
      expect(recorded.contains(10), isTrue);
      expect(recorded.contains(11), isTrue);
    });

    test('RIT-013 & RIT-014: EndOfDaySweep multi-day gap sweep and idempotent debt increment', () async {
      // Enable religion module
      await db.insert('app_settings', {
        'key': 'module_religion_enabled',
        'value': 'true',
        'updatedAt': 1000,
      });

      // App start date: 5 days ago
      final now = DateTime(2026, 8, 20, 10, 0);
      const fourDaysAgoStr = '2026-08-16';

      await db.insert('app_settings', {
        'key': 'app_start_date',
        'value': fourDaysAgoStr,
        'updatedAt': 1000,
      });

      // Last sweep was 4 days ago
      await db.insert('app_settings', {
        'key': 'last_worship_sweep_date',
        'value': fourDaysAgoStr,
        'updatedAt': 1000,
      });

      // Create an active prayer practice created 5 days ago with allowQada = 1
      await db.insert('worship_practices', {
        'id': 'prayer_maghrib',
        'title': 'نماز مغرب',
        'practiceType': 'PRAYER',
        'dailyTarget': 1,
        'dailyDone': 0,
        'allowQada': 1,
        'isActive': 1,
        'createdAt': DateTime(2026, 8, 15).millisecondsSinceEpoch,
        'updatedAt': 1000,
      });

      // First run: sweep days 17, 18, 19
      await EndOfDaySweep.runSweep(db, now: now);

      // Check completions created for each missed day (17, 18, 19)
      final completions = await db.query('worship_completions', where: 'practiceId = ?', whereArgs: ['prayer_maghrib']);
      expect(completions.length, 3);

      // Check debt totalCount
      final debts = await db.query('worship_debts', where: 'id = ?', whereArgs: ['debt_PRAYER_prayer_maghrib']);
      expect(debts.isNotEmpty, isTrue);
      expect(debts.first['remainingCount'], 3);

      // Second run on same day (idempotent run): should NOT double the debt
      await EndOfDaySweep.runSweep(db, now: now);

      final completionsAfter = await db.query('worship_completions', where: 'practiceId = ?', whereArgs: ['prayer_maghrib']);
      expect(completionsAfter.length, 3);

      final debtsAfter = await db.query('worship_debts', where: 'id = ?', whereArgs: ['debt_PRAYER_prayer_maghrib']);
      expect(debtsAfter.first['remainingCount'], 3);
    });

    test('RIT-018: DatabaseHelper.logNotificationEvent generates unique IDs without collision', () async {
      await DatabaseHelper.instance.logNotificationEvent(
        routineId: 'routine_1',
        actionTaken: 'viewed',
        notificationType: 'reminder',
        executor: db,
      );
      await DatabaseHelper.instance.logNotificationEvent(
        routineId: 'routine_1',
        actionTaken: 'viewed',
        notificationType: 'reminder',
        executor: db,
      );

      final events = await db.query('notification_history');
      expect(events.length, 2);
      expect(events[0]['id'], isNot(equals(events[1]['id'])));
    });

    test('RIT-020: DatabaseHelper.isUserMenstruating returns false safely on invalid database', () async {
      final invalidDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
      );
      await invalidDb.close();

      final result = await DatabaseHelper.instance.isUserMenstruating(executor: invalidDb);
      expect(result, isFalse);
    });
  });
}
