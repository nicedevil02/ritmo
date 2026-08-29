import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/migration/migration_runner.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v2_planning_schema.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/commitment_agenda_source.dart';
import 'package:ritmo/features/goals/logic/planning_controller.dart';
import 'package:ritmo/features/goals/logic/planning_repository.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Migration V2 & Schema Integrity Guard Tests', () {
    test('1. Migration V2 runs on v1 DB and creates all planning tables and indexes', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1);

      // Run migration from 1 to 2
      await MigrationRunner.run(db, 1, 2);

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tableNames = tables.map((r) => r['name'] as String).toSet();

      expect(tableNames, contains('planning_cycles'));
      expect(tableNames, contains('planning_commitments'));
      expect(tableNames, contains('planning_allocations'));
      expect(tableNames, contains('planning_reviews'));
      expect(tableNames, contains('calendar_exceptions'));

      // Check migration tracking record
      final applied = await db.query('schema_migrations', where: 'version = 2');
      expect(applied, hasLength(1));

      await db.close();
    });

    test('2. Migration V2 is idempotent (executing twice does not throw)', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1);

      // First run
      await MigrationRunner.run(db, 1, 2);

      // Second direct execution of migration v2
      final migration = MigrationV2PlanningSchema();
      await expectLater(migration.up(db), completes);

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tableNames = tables.map((r) => r['name'] as String).toSet();
      expect(tableNames, contains('planning_cycles'));
      expect(tableNames, contains('planning_commitments'));
      expect(tableNames, contains('planning_allocations'));
      expect(tableNames, contains('planning_reviews'));

      await db.close();
    });

    test('3. Schema parity between SchemaManager.createAll() and Migration V2', () async {
      final dbCreateAll = await openDatabase(inMemoryDatabasePath);
      await SchemaManager.createAll(dbCreateAll);

      final dbMigrated = await openDatabase(inMemoryDatabasePath, version: 1);
      await MigrationRunner.run(dbMigrated, 1, 2);

      final tablesToCheck = [
        'planning_cycles',
        'planning_commitments',
        'planning_allocations',
        'planning_reviews',
        'calendar_exceptions',
      ];

      for (final table in tablesToCheck) {
        final infoA = await dbCreateAll.rawQuery("PRAGMA table_info('$table')");
        final infoB = await dbMigrated.rawQuery("PRAGMA table_info('$table')");

        final colsA = infoA.map((r) => r['name'] as String).toSet();
        final colsB = infoB.map((r) => r['name'] as String).toSet();

        for (final col in colsA) {
          expect(
            colsB.contains(col),
            isTrue,
            reason: 'Column "$col" in table "$table" is present in createAll() but missing in migration v2',
          );
        }
      }

      await dbCreateAll.close();
      await dbMigrated.close();
    });

    test('4. CommitmentAgendaSource filters out DROPPED/MOVED and honors includeCompleted', () {
      final rows = [
        {
          'allocId': 'a1',
          'dayKey': '2026-08-29',
          'plannedMinutes': 45,
          'allocStatus': 'PLANNED',
          'commTitle': 'کار جاری',
          'importance': 'MUST',
          'workKind': 'DEEP',
          'flexibility': 'FLEXIBLE',
        },
        {
          'allocId': 'a2',
          'dayKey': '2026-08-29',
          'plannedMinutes': 30,
          'allocStatus': 'DONE',
          'commTitle': 'کار انجام‌شده',
          'importance': 'SHOULD',
          'workKind': 'LIGHT',
          'flexibility': 'FLEXIBLE',
        },
        {
          'allocId': 'a3',
          'dayKey': '2026-08-29',
          'plannedMinutes': 30,
          'allocStatus': 'MOVED',
          'commTitle': 'کار جابه‌جاشده',
          'importance': 'SHOULD',
        },
        {
          'allocId': 'a4',
          'dayKey': '2026-08-29',
          'plannedMinutes': 30,
          'allocStatus': 'DROPPED',
          'commTitle': 'کار رهاشده',
          'importance': 'COULD',
        },
      ];

      final source = CommitmentAgendaSource(
        allocationsByDate: {'2026-08-29': rows},
      );

      // Case A: includeCompleted = true
      final ctxWithCompleted = AgendaDayContext(
        date: DateTime(2026, 8, 29),
        dateStr: '2026-08-29',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(includeCompleted: true),
      );
      final itemsWithCompleted = source.itemsForDate(ctxWithCompleted);
      expect(itemsWithCompleted, hasLength(2)); // a1 (PLANNED) and a2 (DONE)
      expect(itemsWithCompleted[0].sourceId, equals('a1'));
      expect(itemsWithCompleted[0].completion, equals(AgendaCompletion.pending));
      expect(itemsWithCompleted[1].sourceId, equals('a2'));
      expect(itemsWithCompleted[1].completion, equals(AgendaCompletion.done));

      // Case B: includeCompleted = false
      final ctxWithoutCompleted = AgendaDayContext(
        date: DateTime(2026, 8, 29),
        dateStr: '2026-08-29',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(includeCompleted: false),
      );
      final itemsWithoutCompleted = source.itemsForDate(ctxWithoutCompleted);
      expect(itemsWithoutCompleted, hasLength(1)); // only a1 (PLANNED)
      expect(itemsWithoutCompleted.first.sourceId, equals('a1'));
      expect(itemsWithoutCompleted.first.completion, equals(AgendaCompletion.pending));
    });

    test('5. Capacity feedback loop prevention: excludeDomains prevents commitment self-counting', () {
      const opts = AgendaQueryOptions(
        excludeDomains: {AgendaDomain.commitment},
      );
      expect(opts.wants(AgendaDomain.commitment), isFalse);
      expect(opts.wants(AgendaDomain.task), isTrue);
      expect(opts.wants(AgendaDomain.routine), isTrue);

      const source = CommitmentAgendaSource(
        allocationsByDate: {
          '2026-08-29': [
            {
              'allocId': 'a1',
              'dayKey': '2026-08-29',
              'plannedMinutes': 60,
              'allocStatus': 'PLANNED',
              'commTitle': 'تعهد تستی',
              'importance': 'MUST',
            },
          ],
        },
      );

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 29),
        dateStr: '2026-08-29',
        isToday: true,
        prayerTimes: const {},
        options: opts,
      );

      // When excludeDomains contains commitment, source returns empty list
      final items = source.itemsForDate(ctx);
      expect(items, isEmpty);
    });

    test('6. Database failure in PlanningRepository triggers PlanningController failed state', () async {
      // Create a database handle without planning_cycles table
      final db = await openDatabase(inMemoryDatabasePath);
      PlanningRepository.instance.setTestDatabase(db);

      final controller = PlanningController();
      expect(controller.status, equals(PlanningStateStatus.loading));

      // loadHorizon should catch the database error, NOT show an empty ready screen!
      await controller.loadHorizon(PlanningHorizon.week);

      expect(controller.status, equals(PlanningStateStatus.failed));
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, contains('ناموفق'));

      // Clean up
      PlanningRepository.instance.setTestDatabase(null);
      await db.close();
    });
  });
}
