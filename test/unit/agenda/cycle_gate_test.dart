import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/cycle_agenda_source.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/settings/settings_registry.dart';

void main() {
  group('Phase M1-E: Cycle Gate Simplification & Explicit Consent (P10 / M1-12..M1-14)', () {
    test('show_cycle_in_calendar is registered in SettingsRegistry with default false (privacy-first)', () {
      final desc = SettingsRegistry.all.firstWhere(
        (s) => s.key == 'show_cycle_in_calendar',
        orElse: () => throw Exception('show_cycle_in_calendar not found'),
      );

      expect(desc.group, equals(SettingsGroup.calendar));
      expect(desc.defaultValue, isFalse);
    });

    test('CycleAgendaSource with cycleAllowed: false emits empty items', () {
      const source = CycleAgendaSource(
        cycleOutput: null,
        cycleAllowed: false,
      );

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 15),
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      expect(source.isEnabled, isFalse);
      expect(source.itemsForDate(ctx), isEmpty);
    });

    test('CycleAgendaSource with cycleAllowed: true and valid output produces agenda items', () {
      final now = DateTime(2026, 8, 15);
      final periodStart = now.subtract(const Duration(days: 2));
      final periodEnd = now.add(const Duration(days: 3));

      final output = CycleEngineOutput(
        currentPhase: CyclePhase.menstrual,
        dayOfCycle: 3,
        dayOfPeriod: 3,
        nextPeriodPrediction: periodStart,
        fertileWindowStart: now.add(const Duration(days: 8)),
        fertileWindowEnd: now.add(const Duration(days: 13)),
        ovulationDay: now.add(const Duration(days: 12)),
        isIrregular: false,
        stats: CycleStats(avgCycleLength: 28, avgPeriodDuration: 6, totalRecordedCycles: 3),
        dataMaturity: 'HIGH',
        hasData: true,
        nextPeriodWindowStart: periodStart,
        nextPeriodWindowEnd: periodEnd,
        pmsWindowStart: now.subtract(const Duration(days: 5)),
        pmsWindowEnd: now.subtract(const Duration(days: 3)),
        regularityScore: 90,
        trendPoints: const [],
        regularityLabel: 'منظم',
        predictionDisclaimer: '',
      );

      final source = CycleAgendaSource(
        cycleOutput: output,
        cycleAllowed: true,
      );

      final ctx = AgendaDayContext(
        date: now,
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      expect(source.isEnabled, isTrue);
      final items = source.itemsForDate(ctx);
      expect(items, isNotEmpty);
      expect(items.first.domain, equals(AgendaDomain.cycle));
      expect(items.first.title, contains('چرخه ماهانه'));
    });
  });
}
