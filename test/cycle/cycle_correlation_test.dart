import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/logic/cycle_correlation.dart';
import 'package:ritmo/features/cycle/models/cycle_models.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CycleCorrelationAnalyzer Tests (C-28, C-29)', () {
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
                flowLevel TEXT,
                symptomsJson TEXT,
                mood TEXT,
                notes TEXT,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE energy_logs (
                id TEXT PRIMARY KEY,
                energyLevel TEXT,
                loggedAt INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE bedtime_diagnostics (
                id TEXT PRIMARY KEY,
                date TEXT NOT NULL,
                quality REAL
              )
            ''');
            await db.execute('''
              CREATE TABLE routine_completions (
                id TEXT PRIMARY KEY,
                completionDate TEXT NOT NULL,
                completionTime INTEGER NOT NULL,
                resultType TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE cycle_periods (
                id TEXT PRIMARY KEY,
                startDate TEXT NOT NULL,
                endDate TEXT,
                cycleLength INTEGER,
                periodDuration INTEGER,
                isProjected INTEGER,
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
      'C-28: 3 days of logs does not produce statistically significant correlation (requires n >= 14)',
      () async {
        final now = DateTime(2026, 8, 17);

        // Insert only 3 days
        for (var i = 0; i < 3; i++) {
          final dateStr = '2026-08-${15 + i}';
          final dayTime = DateTime(2026, 8, 15 + i);
          await db.insert('cycle_day_logs', {
            'id': 'log_$i',
            'logDate': dateStr,
            'flowLevel': 'HEAVY',
            'createdAt': dayTime.millisecondsSinceEpoch,
            'updatedAt': dayTime.millisecondsSinceEpoch,
          });
          await db.insert('energy_logs', {
            'id': 'e_$i',
            'energyLevel': 'LOW',
            'loggedAt': dayTime.millisecondsSinceEpoch,
          });
        }

        final results = await CycleCorrelationAnalyzer.analyzeCorrelations(
          db,
          now: now,
        );
        expect(results.length, equals(3));
        for (final corr in results) {
          expect(corr.isSignificant, isFalse);
          expect(corr.sampleSize, lessThan(14));
        }
      },
    );

    test(
      'C-28: Correlation vector includes non-bleeding days (selection bias resolved)',
      () async {
        final now = DateTime(2026, 8, 17);

        // Insert 15 days of data (5 heavy flow, 10 zero flow)
        for (var i = 0; i < 15; i++) {
          final dayDate = DateTime(2026, 8, 1 + i);
          final dateStr = '2026-08-${(1 + i).toString().padLeft(2, '0')}';
          final isBleeding = i < 5;

          await db.insert('cycle_day_logs', {
            'id': 'log_$i',
            'logDate': dateStr,
            'flowLevel': isBleeding ? 'HEAVY' : 'NONE',
            'createdAt': dayDate.millisecondsSinceEpoch,
            'updatedAt': dayDate.millisecondsSinceEpoch,
          });

          await db.insert('energy_logs', {
            'id': 'e_$i',
            'energyLevel': isBleeding ? 'LOW' : 'HIGH',
            'loggedAt': dayDate.millisecondsSinceEpoch,
          });
        }

        final results = await CycleCorrelationAnalyzer.analyzeCorrelations(
          db,
          now: now,
        );
        final energyCorr = results.firstWhere((r) => r.metric == 'انرژی بدنی');

        expect(energyCorr.sampleSize, equals(15));
        expect(energyCorr.isSignificant, isTrue);
        expect(energyCorr.coefficient, isNotNull);
        // Bleeding = Heavy (flow=3) -> Energy Low (1), Non-bleeding = None (flow=0) -> Energy High (3)
        // Strong negative correlation expected
        expect(energyCorr.coefficient!, lessThan(-0.5));
      },
    );

    test(
      'C-29: analyzeSymptomStats handles corrupted logDate and discards days beyond L + 10',
      () async {
        // 1. Insert period starting 2026-08-01
        await db.insert('cycle_periods', {
          'id': 'p1',
          'startDate': '2026-08-01',
          'endDate': '2026-08-06',
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        // 2. Insert valid day log (Day 2 of cycle)
        await db.insert('cycle_day_logs', {
          'id': 'log_valid',
          'logDate': '2026-08-02',
          'symptomsJson': '["cramps", "headache"]',
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        // 3. Insert corrupted logDate
        await db.insert('cycle_day_logs', {
          'id': 'log_corrupt',
          'logDate': 'INVALID_GARBAGE_DATE_STRING',
          'symptomsJson': '["cramps"]',
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        // 4. Insert log 60 days after start (exceeds L + 10 = 38 days)
        await db.insert('cycle_day_logs', {
          'id': 'log_distant',
          'logDate': '2026-09-30',
          'symptomsJson': '["cramps"]',
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        // analyzeSymptomStats must not throw and correctly attribute only valid log
        final stats = await CycleCorrelationAnalyzer.analyzeSymptomStats(
          db,
          defaultCycleLength: 28,
        );
        expect(stats.isNotEmpty, isTrue);

        final crampsStat = stats.firstWhere((s) => s.key == 'cramps');
        expect(
          crampsStat.count,
          equals(1),
        ); // Corrupt date and distant date were skipped
        expect(crampsStat.typicalCycleDay, equals(2));
      },
    );
  });
}
