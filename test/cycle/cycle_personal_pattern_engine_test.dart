import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/logic/cycle_personal_pattern_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CyclePersonalPatternEngine Tests (C-34)', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE cycle_day_logs (
                id TEXT PRIMARY KEY,
                logDate TEXT NOT NULL,
                symptomsJson TEXT,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL
              )
            ''');
          },
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'C-34: Symptom occurring only 2 times is NOT published as forecast (requires minOccurrences = 3)',
      () async {
        final periodRows = [
          {'id': 'p1', 'startDate': '2026-05-01'},
          {'id': 'p2', 'startDate': '2026-05-29'},
          {'id': 'p3', 'startDate': '2026-06-26'},
          {'id': 'p4', 'startDate': '2026-07-24'},
        ];

        // Symptom on Day 14 of Cycle 1 and Cycle 2 (only 2 times)
        await db.insert('cycle_day_logs', {
          'id': 'l1',
          'logDate': '2026-05-14',
          'symptomsJson': '["headache"]',
          'createdAt': 1000,
          'updatedAt': 1000,
        });
        await db.insert('cycle_day_logs', {
          'id': 'l2',
          'logDate': '2026-06-11',
          'symptomsJson': '["headache"]',
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        final forecasts =
            await CyclePersonalPatternEngine.computePersonalForecasts(
              db: db,
              periodRows: periodRows,
              avgCycleLength: 28,
            );

        expect(forecasts.isEmpty, isTrue);
      },
    );

    test(
      'C-34: Symptom occurring 3 times across 3 completed cycles is published with valid confidence',
      () async {
        final periodRows = [
          {'id': 'p1', 'startDate': '2026-05-01'},
          {'id': 'p2', 'startDate': '2026-05-29'},
          {'id': 'p3', 'startDate': '2026-06-26'},
          {'id': 'p4', 'startDate': '2026-07-24'},
        ];

        // Headache on Day 14 in 3 cycles
        await db.insert('cycle_day_logs', {
          'id': 'l1',
          'logDate': '2026-05-14',
          'symptomsJson': '["headache"]',
          'createdAt': 1000,
          'updatedAt': 1000,
        });
        await db.insert('cycle_day_logs', {
          'id': 'l2',
          'logDate': '2026-06-11',
          'symptomsJson': '["headache"]',
          'createdAt': 1000,
          'updatedAt': 1000,
        });
        await db.insert('cycle_day_logs', {
          'id': 'l3',
          'logDate': '2026-07-09',
          'symptomsJson': '["headache"]',
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        final forecasts =
            await CyclePersonalPatternEngine.computePersonalForecasts(
              db: db,
              periodRows: periodRows,
              avgCycleLength: 28,
            );

        expect(forecasts.length, equals(1));
        final f = forecasts.first;
        expect(f.symptomKey, equals('headache'));
        expect(f.likelyCycleDay, equals(14));
        expect(
          f.confidence,
          equals(1.0),
        ); // 3 occurrences / 3 completed cycles = 1.0
      },
    );
  });
}
