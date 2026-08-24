import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/cycle_agenda_source.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CycleAgendaSource Tests (C-36 to C-42)', () {
    late Database db;

    setUp(() async {
      db = await openCycleTestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'C-36: CycleAgendaSource produces actual menstrual item for past recorded period',
      () async {
        // 1. Insert past period: 2026-08-01 to 2026-08-06
        await db.insert('cycle_periods', {
          'id': 'p1',
          'startDate': '2026-08-01',
          'endDate': '2026-08-06',
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        final settings = {
          'user_gender': 'female',
          'module_cycle_enabled': 'true',
          'show_cycle_in_calendar': 'true',
        };

        final source = await CycleAgendaSource.load(db, settings, true);
        expect(source.isEnabled, isTrue);

        final ctx = AgendaDayContext(
          date: DateTime(2026, 8, 3), // Day 3 of past period
          dateStr: '2026-08-03',
          isToday: false,
          prayerTimes: const {},
          options: const AgendaQueryOptions(),
        );

        final items = source.itemsForDate(ctx);
        expect(items.length, equals(1));
        expect(
          items.first.title.contains('Day 3') ||
              items.first.title.contains('3') ||
              items.first.title.contains('۳'),
          isTrue,
        );
        expect(items.first.domain, equals(AgendaDomain.cycle));
      },
    );

    test(
      'C-36: Day in both PMS and prediction windows produces both items without dropping one',
      () {
        final engineOutput = CycleEngineOutput(
          currentPhase: CyclePhase.luteal,
          dayOfCycle: 26,
          dayOfPeriod: 0,
          nextPeriodPrediction: DateTime(2026, 8, 20),
          nextPeriodWindowStart: DateTime(2026, 8, 18),
          nextPeriodWindowEnd: DateTime(2026, 8, 22),
          pmsWindowStart: DateTime(2026, 8, 16),
          pmsWindowEnd: DateTime(2026, 8, 19),
          isIrregular: false,
          stats: CycleStats(avgCycleLength: 28, avgPeriodDuration: 6),
          dataMaturity: 'HIGH',
          hasData: true,
          trendPoints: const [],
        );

        // We test with custom source containing engineOutput
        final populatedSource = CycleAgendaSource(
          cycleOutput: engineOutput,
          cycleAllowed: true,
          periodRows: const [],
          isPregnancy: false,
        );

        // Date: 2026-08-18 (Overlaps both PMS [16..19] and Period Prediction [18..22])
        final ctx = AgendaDayContext(
          date: DateTime(2026, 8, 18),
          dateStr: '2026-08-18',
          isToday: false,
          prayerTimes: const {},
          options: const AgendaQueryOptions(),
        );

        final items = populatedSource.itemsForDate(ctx);
        expect(items.length, equals(2));
        expect(
          items.any((i) => i.title.contains('پیش‌بینی دوره قاعدگی') || i.title.contains('Period Prediction Window')),
          isTrue,
        );
        expect(items.any((i) => i.title.contains('PMS')), isTrue);
      },
    );

    test(
      'C-36: In pregnancy mode, zero period/fertile predictions are produced',
      () {
        final pregnancyOutput = CycleEngineOutput(
          currentPhase: CyclePhase.pregnancy,
          dayOfCycle: 0,
          dayOfPeriod: 0,
          nextPeriodPrediction: null,
          nextPeriodWindowStart: null,
          nextPeriodWindowEnd: null,
          isIrregular: false,
          stats: CycleStats(avgCycleLength: 28, avgPeriodDuration: 6),
          dataMaturity: 'HIGH',
          hasData: true,
          trendPoints: const [],
        );

        final source = CycleAgendaSource(
          cycleOutput: pregnancyOutput,
          cycleAllowed: true,
          periodRows: const [],
          isPregnancy: true,
        );

        final ctx = AgendaDayContext(
          date: DateTime(2026, 8, 20),
          dateStr: '2026-08-20',
          isToday: false,
          prayerTimes: const {},
          options: const AgendaQueryOptions(),
        );

        final items = source.itemsForDate(ctx);
        expect(items.isEmpty, isTrue);
      },
    );
  });
}
