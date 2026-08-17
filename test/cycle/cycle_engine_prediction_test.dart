// C-17, C-19, C-22, C-25, C-26: CycleEngine Prediction & Outlier Tests
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CycleEngine Prediction Tests', () {
    late Database db;
    late CycleEngine engine;

    setUp(() async {
      databaseFactory = databaseFactoryFfi;
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT,
            updatedAt INTEGER
          )
        ''');
          await db.execute('''
          CREATE TABLE cycle_periods (
            id TEXT PRIMARY KEY,
            startDate TEXT NOT NULL,
            endDate TEXT,
            flowIntensity TEXT,
            isPredicted INTEGER DEFAULT 0,
            note TEXT,
            createdAt INTEGER,
            updatedAt INTEGER
          )
        ''');
        },
      );

      engine = CycleEngine();

      await db.insert('app_settings', {
        'key': 'user_gender',
        'value': 'FEMALE',
      });
      await db.insert('app_settings', {
        'key': 'module_cycle_enabled',
        'value': 'true',
      });
      await db.insert('app_settings', {
        'key': 'cycle_avg_length',
        'value': '28',
      });
      await db.insert('app_settings', {
        'key': 'cycle_avg_period',
        'value': '6',
      });
      await db.insert('app_settings', {
        'key': 'cycle_luteal_phase_days',
        'value': '14',
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('C-25: _emptyOutput returns null for all prediction fields', () async {
      final now = DateTime(2026, 8, 17);
      final settings = {
        'user_gender': 'FEMALE',
        'module_cycle_enabled': 'true',
      };

      final output = await engine.calculate(
        CycleEngineInput(db: db, appSettings: settings, now: now),
      );

      expect(output.hasData, isFalse);
      expect(output.currentPhase, equals(CyclePhase.noData));
      expect(output.nextPeriodPrediction, isNull);
      expect(output.fertileWindowStart, isNull);
      expect(output.fertileWindowEnd, isNull);
      expect(output.ovulationDay, isNull);
      expect(output.nextPeriodWindowStart, isNull);
      expect(output.nextPeriodWindowEnd, isNull);
      expect(output.pmsWindowStart, isNull);
      expect(output.pmsWindowEnd, isNull);
      expect(output.regularityScore, isNull);
    });

    test(
      'C-17: Prediction window is clamped to at most 7 days wide even across multiple elapsed cycles',
      () async {
        // Seed historical records with variable cycle lengths
        await db.insert('cycle_periods', {
          'id': '1',
          'startDate': '2026-01-01',
          'endDate': '2026-01-06',
        });
        await db.insert('cycle_periods', {
          'id': '2',
          'startDate': '2026-01-26',
          'endDate': '2026-01-31',
        }); // 25 days
        await db.insert('cycle_periods', {
          'id': '3',
          'startDate': '2026-03-05',
          'endDate': '2026-03-10',
        }); // 38 days

        final settings = {
          'user_gender': 'FEMALE',
          'module_cycle_enabled': 'true',
        };

        // Historical cycles have high dispersion (25 vs 38 days -> 13 days spread)
        final now = DateTime(2026, 3, 20);
        final output = await engine.calculate(
          CycleEngineInput(db: db, appSettings: settings, now: now),
        );

        expect(output.hasData, isTrue);
        expect(output.nextPeriodWindowStart, isNotNull);
        expect(output.nextPeriodWindowEnd, isNotNull);
        final windowWidth = output.nextPeriodWindowEnd!
            .difference(output.nextPeriodWindowStart!)
            .inDays;
        expect(windowWidth, lessThanOrEqualTo(7));
      },
    );

    test(
      'C-19: Short cycle (L = 21, pDuration = 10) allows ovulation phase to be reachable',
      () async {
        await db.insert('cycle_periods', {
          'id': '1',
          'startDate': '2026-08-01',
          'endDate': '2026-08-10',
        });

        final settings = {
          'user_gender': 'FEMALE',
          'module_cycle_enabled': 'true',
          'cycle_avg_length': '21',
          'cycle_avg_period': '10',
          'cycle_luteal_phase_days': '14',
        };

        // For L=21, luteal days is clamped to min(14, 21-10) = 11 days.
        // Ovulation day = 21 - 11 = Day 10.
        // On day 11 (2026-08-11), phase is ovulation!
        final now = DateTime(2026, 8, 11);
        final output = await engine.calculate(
          CycleEngineInput(db: db, appSettings: settings, now: now),
        );

        expect(output.currentPhase, equals(CyclePhase.ovulation));
      },
    );

    test(
      'C-22: 50-day cycle outlier in history is discarded and counted in discardedOutliers',
      () async {
        await db.insert('cycle_periods', {
          'id': '1',
          'startDate': '2026-01-01',
          'endDate': '2026-01-06',
        });
        await db.insert('cycle_periods', {
          'id': '2',
          'startDate': '2026-02-20',
          'endDate': '2026-02-25',
        }); // 50 days (outlier)
        await db.insert('cycle_periods', {
          'id': '3',
          'startDate': '2026-03-20',
          'endDate': '2026-03-25',
        }); // 28 days

        final settings = {
          'user_gender': 'FEMALE',
          'module_cycle_enabled': 'true',
        };

        final now = DateTime(2026, 4, 1);
        final output = await engine.calculate(
          CycleEngineInput(db: db, appSettings: settings, now: now),
        );

        expect(output.discardedOutliers, equals(1));
        expect(
          output.stats.completedCycles,
          equals(1),
        ); // Only the 28 day cycle was plausible
      },
    );

    test(
      'C-26: All periods in the future flags output as isProjected',
      () async {
        await db.insert('cycle_periods', {
          'id': '1',
          'startDate': '2026-10-01',
          'endDate': '2026-10-06',
        });

        final settings = {
          'user_gender': 'FEMALE',
          'module_cycle_enabled': 'true',
        };

        final now = DateTime(2026, 8, 1);
        final output = await engine.calculate(
          CycleEngineInput(db: db, appSettings: settings, now: now),
        );

        expect(output.isProjected, isTrue);
      },
    );
  });
}
