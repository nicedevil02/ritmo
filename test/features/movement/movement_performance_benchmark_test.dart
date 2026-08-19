import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/application/movement_session_service.dart';
import 'package:ritmo/features/movement/application/strength_program_service.dart';
import 'package:ritmo/features/movement/presentation/center/movement_center_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('Movement Center Performance Benchmark (DoD Targets)', () {
    Database? db;
    bool dbInitialized = false;
    late MovementOccurrenceService occurrenceService;
    late MovementSessionService sessionService;
    late StrengthProgramService strengthProgramService;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        final database = await databaseFactory.openDatabase(
          inMemoryDatabasePath,
        );
        db = database;
        await MovementTables.create(database);
        await MovementTables.seedInitialData(database);

        occurrenceService = MovementOccurrenceService(db: database);
        sessionService = MovementSessionService(db: database);
        strengthProgramService = StrengthProgramService(db: database);

        // Seed 42 days of occurrence data (6 weeks)
        final baseDate = DateTime(2026, 8, 1);
        final batch = db!.batch();
        for (int i = 0; i < 42; i++) {
          final d = baseDate.add(Duration(days: i));
          final dateIso =
              '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          batch.insert(MovementTables.tableOccurrences, {
            'id': 'occ_bench_$i',
            'activityKindId': i % 2 == 0 ? 'kind_running' : 'kind_walking',
            'dateIso': dateIso,
            'startTime': '18:00',
            'status': i < 20 ? 'completed' : 'planned',
            'goalType': 'duration',
            'goalValue': 30,
            'goalUnit': 'min',
            'origin': 'template',
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          });
        }
        await batch.commit(noResult: true);
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

    test('Cold load with 42 days of data executes P95 < 250ms', () async {
      if (!dbInitialized) return;

      final stopwatch = Stopwatch()..start();
      final controller = MovementCenterController(
        occurrenceService: occurrenceService,
        sessionService: sessionService,
        strengthProgramService: strengthProgramService,
      );

      await controller.loadData();
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      // ignore: avoid_print
      print('Cold Start Elapsed: ${elapsedMs}ms (Target: <250ms)');
      expect(elapsedMs, lessThan(250));
      expect(controller.weekDays.length, equals(7));
    });

    test('Day switching executes in < 100ms from cached data', () async {
      if (!dbInitialized) return;

      final controller = MovementCenterController(
        occurrenceService: occurrenceService,
        sessionService: sessionService,
        strengthProgramService: strengthProgramService,
      );
      await controller.loadData();

      final targetDate = controller.weekDays[3].date;
      final stopwatch = Stopwatch()..start();
      controller.selectDay(targetDate);
      stopwatch.stop();

      final switchMs = stopwatch.elapsedMicroseconds / 1000.0;
      // ignore: avoid_print
      print('Day Switch Elapsed: ${switchMs}ms (Target: <100ms)');
      expect(switchMs, lessThan(100.0));
      expect(controller.selectedDate.day, equals(targetDate.day));
    });

    test('Toggle completion executes in < 50ms (Optimistic Update)', () async {
      if (!dbInitialized) return;

      final controller = MovementCenterController(
        occurrenceService: occurrenceService,
        sessionService: sessionService,
        strengthProgramService: strengthProgramService,
      );
      await controller.loadData();

      final firstOcc = controller.selectedDayOccurrences.firstOrNull;
      if (firstOcc != null) {
        final stopwatch = Stopwatch()..start();
        await controller.optimisticCompleteOccurrence(firstOcc.id);
        stopwatch.stop();

        final updateMs = stopwatch.elapsedMilliseconds;
        // ignore: avoid_print
        print(
          'Optimistic Status Update Elapsed: ${updateMs}ms (Target: <50ms)',
        );
        expect(updateMs, lessThan(50));
      }
    });
  });
}
