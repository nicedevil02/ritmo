// C-17, C-19, C-22, C-25, C-26: CycleEngine Prediction & Outlier Tests
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CycleEngine Prediction Tests', () {
    late Database db;
    late CycleEngine engine;

    setUp(() async {
      db = await openCycleTestDb();
      engine = CycleEngine();
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
      'F-10 & F-11: Forecast sigma grows with distance and confidence damps',
      () async {
        // Seed historical records with variable cycle lengths
        await db.insert('cycle_periods', {
          'id': '1',
          'startDate': '2026-01-01',
          'endDate': '2026-01-06',
        });
        await db.insert('cycle_periods', {
          'id': '2',
          'startDate': '2026-01-29',
          'endDate': '2026-02-03',
        }); // 28 days
        await db.insert('cycle_periods', {
          'id': '3',
          'startDate': '2026-02-26',
          'endDate': '2026-03-03',
        }); // 28 days
        await db.insert('cycle_periods', {
          'id': '4',
          'startDate': '2026-03-26',
          'endDate': '2026-03-31',
        }); // 28 days

        final settings = {
          'user_gender': 'FEMALE',
          'module_cycle_enabled': 'true',
        };

        final now = DateTime(2026, 3, 27);
        final output = await engine.calculate(
          CycleEngineInput(db: db, appSettings: settings, now: now),
        );

        expect(output.hasData, isTrue);
        expect(output.forecast.length, 12);

        // Verify sigma non-decreasing and confidence non-increasing
        for (var i = 0; i < output.forecast.length - 1; i++) {
          final curr = output.forecast[i];
          final next = output.forecast[i + 1];
          expect(
            next.sigmaDays,
            greaterThanOrEqualTo(curr.sigmaDays),
            reason:
                'sigmaDays at index ${next.index} should be >= index ${curr.index}',
          );
          expect(
            next.confidence,
            lessThanOrEqualTo(curr.confidence),
            reason:
                'confidence at index ${next.index} should be <= index ${curr.index}',
          );
        }

        // Backward compatibility check
        expect(
          output.nextPeriodPrediction,
          output.forecast.first.predictedStart,
        );
        expect(output.ovulationDay, output.forecast.first.ovulationDay);
        expect(output.fertileWindowStart, output.forecast.first.fertileStart);
        expect(output.fertileWindowEnd, output.forecast.first.fertileEnd);
        expect(output.nextPeriodWindowStart, output.forecast.first.windowStart);
        expect(output.nextPeriodWindowEnd, output.forecast.first.windowEnd);
      },
    );

    test(
      'F-13: Ovulation and fertile window are always populated in forecast',
      () async {
        await db.insert('cycle_periods', {
          'id': '1',
          'startDate': '2026-01-01',
          'endDate': '2026-01-06',
        });
        final settings = {
          'user_gender': 'FEMALE',
          'module_cycle_enabled': 'true',
        };
        final now = DateTime(2026, 1, 15);
        final output = await engine.calculate(
          CycleEngineInput(db: db, appSettings: settings, now: now),
        );
        expect(output.forecast.isNotEmpty, isTrue);
        for (final cycle in output.forecast) {
          expect(cycle.ovulationDay, isNotNull);
          expect(cycle.fertileStart, isNotNull);
          expect(cycle.fertileEnd, isNotNull);
        }
        expect(output.ovulationDay, isNotNull);
        expect(output.fertileWindowStart, isNotNull);
      },
    );

    test(
      'F-16: Stale/overdue data produces at most 3 cycles with low confidence',
      () async {
        await db.insert('cycle_periods', {
          'id': '1',
          'startDate': '2026-01-01',
          'endDate': '2026-01-06',
        });
        final settings = {
          'user_gender': 'FEMALE',
          'module_cycle_enabled': 'true',
        };
        // 80 days later -> needsUserAttention / dataStale
        final now = DateTime(2026, 3, 22);
        final output = await engine.calculate(
          CycleEngineInput(db: db, appSettings: settings, now: now),
        );
        expect(output.needsUserAttention, isTrue);
        expect(output.currentPhase, equals(CyclePhase.dataStale));
        expect(output.forecast.length, 3);
        for (final cycle in output.forecast) {
          expect(cycle.confidenceLevel, PredictionConfidenceLevel.low);
        }
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
