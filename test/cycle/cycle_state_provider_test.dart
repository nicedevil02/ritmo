// F-18..F-24: CycleStateProvider and Horizon Management Tests
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/models/cycle_forecast_models.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:ritmo/features/cycle/logic/cycle_state_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CycleStateNotifier & Horizon Extension Tests (F-18..F-24)', () {
    late Database db;

    setUp(() async {
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);

      final engine = CycleEngine();
      final registry = EngineRegistry()..register(engine);
      RitmoEngineBus.init(registry);
    });

    tearDown(() async {
      CycleClock.reset();
      await db.close();
    });

    test(
      'F-18: ensureHorizonCovers does nothing if target day is within forecast',
      () async {
        final now = DateTime(2026, 8, 1);
        CycleClock.nowProvider = () => now;

        await db.insert('cycle_periods', {
          'id': 'p1',
          'startDate': '2026-07-20',
          'endDate': '2026-07-25',
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        final notifier = CycleStateNotifier();
        await notifier.loadState();

        expect(notifier.value.engineOutput?.forecast.length, 12);
        final initialHorizon = notifier.value.horizonCycles;
        final coveredDay = now.add(
          const Duration(days: 60),
        ); // ~2 cycles out, well within 12 cycles

        int notificationCount = 0;
        notifier.addListener(() {
          notificationCount++;
        });

        await notifier.ensureHorizonCovers(coveredDay);

        expect(notifier.value.horizonCycles, initialHorizon);
        expect(
          notificationCount,
          0,
          reason: 'Should not recompute or notify if already covered',
        );
      },
    );

    test(
      'F-18: ensureHorizonCovers extends horizon when target day is beyond forecast',
      () async {
        final now = DateTime(2026, 1, 1);
        CycleClock.nowProvider = () => now;

        await db.insert('cycle_periods', {
          'id': 'p1',
          'startDate': '2026-01-01',
          'endDate': '2026-01-06',
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        final notifier = CycleStateNotifier();
        await notifier.loadState();

        expect(notifier.value.engineOutput?.forecast.length, 12);

        // Target day: 18 months (~540 days) later -> needs ~19-20 cycles
        final distantDay = DateTime(2027, 7, 1);
        await notifier.ensureHorizonCovers(distantDay);

        expect(notifier.value.horizonCycles, greaterThan(12));
        expect(
          notifier.value.engineOutput?.forecast.length,
          notifier.value.horizonCycles,
        );
        expect(
          notifier.value.engineOutput!.forecast.last.predictedEnd.isAfter(
                distantDay,
              ) ||
              notifier.value.horizonCycles == CycleEngine.maxHorizonCycles,
          isTrue,
        );
      },
    );

    test(
      'F-20: Forgotten open period degrades all forecast confidence levels to low',
      () async {
        final now = DateTime(2026, 8, 1);
        CycleClock.nowProvider = () => now;

        // A period started 40 days ago and never closed -> forgotten open period
        await db.insert('cycle_periods', {
          'id': 'p1',
          'startDate': '2026-06-20',
          'endDate': null,
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        final notifier = CycleStateNotifier();
        await notifier.loadState();

        expect(notifier.value.dataQuality?.hasForgottenOpenPeriod, isTrue);
        for (final cycle
            in notifier.value.engineOutput?.forecast ?? <PredictedCycle>[]) {
          expect(cycle.confidenceLevel, PredictionConfidenceLevel.low);
        }
      },
    );

    test(
      'F-22: symptomForecasts are computed and populated in CycleState',
      () async {
        final now = DateTime(2026, 8, 1);
        CycleClock.nowProvider = () => now;

        // 4 periods = 3 completed cycles
        await db.insert('cycle_periods', {
          'id': 'p1',
          'startDate': '2026-05-01',
          'endDate': '2026-05-06',
          'createdAt': 1000,
          'updatedAt': 1000,
        });
        await db.insert('cycle_day_logs', {
          'id': 'l1',
          'logDate': '2026-05-26',
          'symptomsJson': '["headache"]',
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        await db.insert('cycle_periods', {
          'id': 'p2',
          'startDate': '2026-05-29',
          'endDate': '2026-06-03',
          'createdAt': 1000,
          'updatedAt': 1000,
        });
        await db.insert('cycle_day_logs', {
          'id': 'l2',
          'logDate': '2026-06-23',
          'symptomsJson': '["headache"]',
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        await db.insert('cycle_periods', {
          'id': 'p3',
          'startDate': '2026-06-26',
          'endDate': '2026-07-01',
          'createdAt': 1000,
          'updatedAt': 1000,
        });
        await db.insert('cycle_day_logs', {
          'id': 'l3',
          'logDate': '2026-07-21',
          'symptomsJson': '["headache"]',
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        await db.insert('cycle_periods', {
          'id': 'p4',
          'startDate': '2026-07-24',
          'endDate': '2026-07-29',
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        final notifier = CycleStateNotifier();
        await notifier.loadState();

        expect(notifier.value.symptomForecasts, isNotNull);
        // We expect personal pattern engine to identify the recurring symptom pattern
        expect(
          notifier.value.symptomForecasts.any(
            (s) => s.symptomKey == 'headache',
          ),
          isTrue,
        );
      },
    );
  });
}
