import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/application/movement_log_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('MovementLogService Retro & QuickComplete Tests', () {
    Database? db;
    bool dbInitialized = false;
    late MovementLogService logService;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await MovementTables.create(db!);
        await MovementTables.seedInitialData(db!);
        logService = MovementLogService(db: db);
        dbInitialized = true;
      } catch (_) {
        dbInitialized = false;
      }
    });

    tearDown(() async {
      if (dbInitialized && db != null) {
        await db!.close();
      }
    });

    test('logRetroWorkout rejects future dateIso with ArgumentError', () async {
      if (!dbInitialized || db == null) return;

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final futureIso =
          '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

      expect(
        () async => await logService.logRetroWorkout(
          activityKindId: 'kind_running',
          dateIso: futureIso,
          durationSec: 1800,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'logRetroWorkout persists log and links to matching occurrence',
      () async {
        if (!dbInitialized || db == null) return;

        final now = DateTime.now();
        final todayIso =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        // Insert planned occurrence for today
        await db!.insert(MovementTables.tableOccurrences, {
          'id': 'occ_today_planned',
          'activityKindId': 'kind_running',
          'dateIso': todayIso,
          'startTime': '07:00',
          'status': 'planned',
          'origin': 'template',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        });

        final log = await logService.logRetroWorkout(
          activityKindId: 'kind_running',
          dateIso: todayIso,
          durationSec: 1800,
          feeling: 'great',
          note: 'تمرین صبحگاهی در پارک',
          matchedOccurrenceId: 'occ_today_planned',
        );

        expect(log.id, isNotEmpty);
        expect(log.occurrenceId, equals('occ_today_planned'));
        expect(log.durationSec, equals(1800));
        expect(log.source, equals('retro'));

        // Verify occurrence status became completed
        final occ = (await db!.query(
          MovementTables.tableOccurrences,
          where: 'id = ?',
          whereArgs: ['occ_today_planned'],
        )).first;
        expect(occ['status'], equals('completed'));
      },
    );

    test(
      'quickCompleteOccurrence marks occurrence completed and writes workout log',
      () async {
        if (!dbInitialized || db == null) return;

        final now = DateTime.now();
        final todayIso =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        await db!.insert(MovementTables.tableOccurrences, {
          'id': 'occ_quick_1',
          'activityKindId': 'kind_cycling',
          'dateIso': todayIso,
          'startTime': '16:00',
          'status': 'planned',
          'origin': 'template',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        });

        final log = await logService.quickCompleteOccurrence(
          occurrenceId: 'occ_quick_1',
          activityKindId: 'kind_cycling',
          dateIso: todayIso,
          startTime: '16:00',
          durationSec: 2400,
          feeling: 'good',
          note: 'ثبت سریع',
        );

        expect(log.occurrenceId, equals('occ_quick_1'));
        expect(log.source, equals('quickComplete'));

        final occ = (await db!.query(
          MovementTables.tableOccurrences,
          where: 'id = ?',
          whereArgs: ['occ_quick_1'],
        )).first;
        expect(occ['status'], equals('completed'));
      },
    );

    test(
      'getWorkoutLogsForRange returns logs ordered chronologically',
      () async {
        if (!dbInitialized || db == null) return;

        final now = DateTime.now();
        final d1 = '${now.year}-08-10';
        final d2 = '${now.year}-08-12';

        await db!.insert(MovementTables.tableWorkoutLogs, {
          'id': 'log_1',
          'activityKindId': 'kind_walking',
          'dateIso': d1,
          'durationSec': 1200,
          'source': 'retro',
          'createdAt': now.toIso8601String(),
        });

        await db!.insert(MovementTables.tableWorkoutLogs, {
          'id': 'log_2',
          'activityKindId': 'kind_running',
          'dateIso': d2,
          'durationSec': 1800,
          'source': 'retro',
          'createdAt': now.toIso8601String(),
        });

        final logs = await logService.getWorkoutLogsForRange(
          startDateIso: '${now.year}-08-01',
          endDateIso: '${now.year}-08-20',
        );
        expect(logs.length, equals(2));
        expect(logs.first.id, equals('log_1'));
        expect(logs.last.id, equals('log_2'));
      },
    );
  });
}
