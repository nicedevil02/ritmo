// Unit tests for CycleEngine (C-16, C-19)
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';

void main() {
  group('CycleEngine Output Calculations (C-16, C-19)', () {
    test('Calculates luteal phase and ovulation day accurately', () {
      final engine = CycleEngine();
      final startDate = DateTime(2026, 5, 1);
      final now = DateTime(2026, 5, 14); // 13 days in
      const L = 28;
      const pDuration = 6;
      const lutealPhaseDays = 14;

      // Ovulation day = 28 - 14 = 14
      final output = engine.evaluateWithStartForTesting(
        startDate: startDate,
        now: now,
        cycleLength: L,
        periodDuration: pDuration,
        lutealPhaseDays: lutealPhaseDays,
        isIrregular: false,
        stats: CycleStats(
          avgCycleLength: 28,
          avgPeriodDuration: 6,
          totalRecordedCycles: 1,
        ),
        dataMaturity: 'MEDIUM',
        endDate: DateTime(2026, 5, 6),
        trendPoints: [],
        regularityScore: 90,
        pmsWindowDays: 4,
        sd: 1.0,
        cycleLengths: [28],
      );

      expect(output.currentPhase, CyclePhase.ovulation);
      expect(output.dayOfCycle, 14);
      expect(
        output.ovulationDay,
        DateTime(2026, 5, 15),
      ); // 2026-05-29 - 14 days
      expect(output.nextPeriodPrediction, DateTime(2026, 5, 29));
      expect(output.fertileWindowStart, DateTime(2026, 5, 10)); // ovulation - 5
      expect(output.fertileWindowEnd, DateTime(2026, 5, 16)); // ovulation + 1
    });

    test('Menstrual phase active when within bleeding range', () {
      final engine = CycleEngine();
      final startDate = DateTime(2026, 5, 1);
      final now = DateTime(2026, 5, 3); // Day 3

      final output = engine.evaluateWithStartForTesting(
        startDate: startDate,
        now: now,
        cycleLength: 28,
        periodDuration: 6,
        lutealPhaseDays: 14,
        isIrregular: false,
        stats: CycleStats(
          avgCycleLength: 28,
          avgPeriodDuration: 6,
          totalRecordedCycles: 1,
        ),
        dataMaturity: 'MEDIUM',
        endDate: null, // open period
        trendPoints: [],
        regularityScore: 90,
        pmsWindowDays: 4,
        sd: 1.0,
        cycleLengths: [28],
      );

      expect(output.currentPhase, CyclePhase.menstrual);
      expect(output.dayOfPeriod, 3);
    });

    test('Luteal phase when past ovulation day', () {
      final engine = CycleEngine();
      final startDate = DateTime(2026, 5, 1);
      final now = DateTime(2026, 5, 20); // Day 20

      final output = engine.evaluateWithStartForTesting(
        startDate: startDate,
        now: now,
        cycleLength: 28,
        periodDuration: 6,
        lutealPhaseDays: 14,
        isIrregular: false,
        stats: CycleStats(
          avgCycleLength: 28,
          avgPeriodDuration: 6,
          totalRecordedCycles: 1,
        ),
        dataMaturity: 'MEDIUM',
        endDate: DateTime(2026, 5, 6),
        trendPoints: [],
        regularityScore: 90,
        pmsWindowDays: 4,
        sd: 1.0,
        cycleLengths: [28],
      );

      expect(output.currentPhase, CyclePhase.luteal);
      expect(output.dayOfCycle, 20);
    });

    test(
      'Pregnancy mode output suppresses bleeding predictions and marks hasData true',
      () {
        final engine = CycleEngine();
        final now = DateTime(2026, 5, 1);
        final output = engine.pregnancyOutputForTesting(now);

        expect(output.hasData, true);
        expect(output.regularityLevel, RegularityLevel.pregnancy);
        expect(output.dayOfPeriod, 0);
        expect(output.dayOfCycle, 0);
      },
    );
  });
}
