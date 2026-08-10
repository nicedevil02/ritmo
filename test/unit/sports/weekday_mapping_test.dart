import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/ss_program_calendar.dart';

void main() {
  group('Prompt 066 — Test 1: Weekday Mapping Roundtrip & ritmoDayOf (C-01)', () {
    test('legacySsDayToRitmoDay and ritmoDayToLegacySsDay preserve roundtrip for all 7 days', () {
      // Legacy SS mapping: 1=Sat, 2=Sun, 3=Mon, 4=Tue, 5=Wed, 6=Thu, 7=Fri
      // Ritmo global mapping: 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun
      for (int ssDay = 1; ssDay <= 7; ssDay++) {
        final ritmoDay = SsProgramCalendar.legacySsDayToRitmoDay(ssDay);
        final backToSsDay = SsProgramCalendar.ritmoDayToLegacySsDay(ritmoDay);
        expect(backToSsDay, equals(ssDay), reason: 'Failed roundtrip for ssDay=$ssDay');
      }

      for (int ritmoDay = 1; ritmoDay <= 7; ritmoDay++) {
        final ssDay = SsProgramCalendar.ritmoDayToLegacySsDay(ritmoDay);
        final backToRitmoDay = SsProgramCalendar.legacySsDayToRitmoDay(ssDay);
        expect(backToRitmoDay, equals(ritmoDay), reason: 'Failed roundtrip for ritmoDay=$ritmoDay');
      }
    });

    test('ritmoDayOf returns standard DateTime.weekday (1:Mon .. 7:Sun)', () {
      // 2026-08-10 is a Monday (1 in Ritmo/DateTime)
      final mon = DateTime(2026, 8, 10);
      expect(SsProgramCalendar.ritmoDayOf(mon), equals(1));

      // 2026-08-15 is a Saturday (6 in Ritmo/DateTime, 1 in legacy SS)
      final sat = DateTime(2026, 8, 15);
      expect(SsProgramCalendar.ritmoDayOf(sat), equals(6));
      expect(SsProgramCalendar.ritmoDayToLegacySsDay(6), equals(1));
    });
  });

  group('Prompt 066 — Test 2: Program Calendar Cycle Week & Deload (C-02, T-B1)', () {
    test('cycleWeekFor computes correct 1..4 cycle week from programStart', () {
      final start = DateTime(2026, 8, 1); // Day 1
      expect(SsProgramCalendar.cycleWeekFor(DateTime(2026, 8, 1), programStart: start), equals(1));
      expect(SsProgramCalendar.cycleWeekFor(DateTime(2026, 8, 7), programStart: start), equals(1));
      expect(SsProgramCalendar.cycleWeekFor(DateTime(2026, 8, 8), programStart: start), equals(2));
      expect(SsProgramCalendar.cycleWeekFor(DateTime(2026, 8, 22), programStart: start), equals(4));
      expect(SsProgramCalendar.cycleWeekFor(DateTime(2026, 8, 29), programStart: start), equals(1)); // Cycles back
    });

    test('isDeloadWeek detects 4th week deload correctly', () {
      expect(SsProgramCalendar.isDeloadWeek(4, deloadEveryNWeeks: 4), isTrue);
      expect(SsProgramCalendar.isDeloadWeek(3, deloadEveryNWeeks: 4), isFalse);
      expect(SsProgramCalendar.isDeloadWeek(4, deloadEveryNWeeks: 0), isFalse);
    });
  });
}
