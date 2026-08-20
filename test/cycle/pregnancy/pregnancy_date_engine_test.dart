import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_engine.dart';

void main() {
  group('PregnancyDateEngine Tests (PRG-07)', () {
    test('calculateEddFromLmp adds exactly 280 days and cleans time', () {
      final lmp = DateTime(2026, 1, 1, 14, 30);
      final edd = PregnancyDateEngine.calculateEddFromLmp(lmp);
      expect(edd, equals(DateTime(2026, 10, 8)));
      expect(edd.hour, equals(0));
      expect(edd.minute, equals(0));
    });

    test('calculateLmpFromEdd subtracts exactly 280 days and cleans time', () {
      final edd = DateTime(2026, 10, 8, 22, 15);
      final lmp = PregnancyDateEngine.calculateLmpFromEdd(edd);
      expect(lmp, equals(DateTime(2026, 1, 1)));
      expect(lmp.hour, equals(0));
    });

    test('calculateEddFromConception adds exactly 266 days', () {
      final conception = DateTime(2026, 1, 15);
      final edd = PregnancyDateEngine.calculateEddFromConception(conception);
      expect(edd, equals(DateTime(2026, 10, 8)));
    });

    test('calculateEddFromUltrasound calculates Robinson CRL dating', () {
      final ultrasoundDate = DateTime(2026, 3, 1);
      // For CRL = 10mm -> GA ~= 49 days (7 weeks), remaining = 231 days
      final edd10 = PregnancyDateEngine.calculateEddFromUltrasound(
        ultrasoundDate: ultrasoundDate,
        crownRumpLengthMm: 10,
      );
      expect(edd10.isAfter(ultrasoundDate), isTrue);
      final daysDiff10 = edd10.difference(ultrasoundDate).inDays;
      expect(daysDiff10, inInclusiveRange(225, 235));

      // For CRL = 84mm -> GA ~= 98 days (14 weeks), remaining = 182 days
      final edd84 = PregnancyDateEngine.calculateEddFromUltrasound(
        ultrasoundDate: ultrasoundDate,
        crownRumpLengthMm: 84,
      );
      final daysDiff84 = edd84.difference(ultrasoundDate).inDays;
      expect(daysDiff84, inInclusiveRange(178, 186));
    });

    test(
      'calculateCurrentGestation handles day 0, day 14, day 280, and post-term day 285',
      () {
        final lmp = DateTime(2026, 1, 1);

        // Day 0 (LMP day)
        final ga0 = PregnancyDateEngine.calculateCurrentGestation(
          lmp: lmp,
          now: DateTime(2026, 1, 1),
        );
        expect(ga0.totalDays, equals(0));
        expect(ga0.weeks, equals(0));
        expect(ga0.days, equals(0));

        // Day 14 (2 weeks)
        final ga14 = PregnancyDateEngine.calculateCurrentGestation(
          lmp: lmp,
          now: DateTime(2026, 1, 15),
        );
        expect(ga14.totalDays, equals(14));
        expect(ga14.weeks, equals(2));
        expect(ga14.days, equals(0));

        // Day 280 (40 weeks)
        final ga280 = PregnancyDateEngine.calculateCurrentGestation(
          lmp: lmp,
          now: DateTime(2026, 10, 8),
        );
        expect(ga280.totalDays, equals(280));
        expect(ga280.weeks, equals(40));
        expect(ga280.days, equals(0));

        // Day 285 (40 weeks + 5 days)
        final ga285 = PregnancyDateEngine.calculateCurrentGestation(
          lmp: lmp,
          now: DateTime(2026, 10, 13),
        );
        expect(ga285.totalDays, equals(285));
        expect(ga285.weeks, equals(40));
        expect(ga285.days, equals(5));
      },
    );

    test('calculateTrimester correctly maps day boundaries', () {
      expect(PregnancyDateEngine.calculateTrimester(1), equals(1));
      expect(PregnancyDateEngine.calculateTrimester(91), equals(1));
      expect(PregnancyDateEngine.calculateTrimester(92), equals(2));
      expect(PregnancyDateEngine.calculateTrimester(189), equals(2));
      expect(PregnancyDateEngine.calculateTrimester(190), equals(3));
      expect(PregnancyDateEngine.calculateTrimester(280), equals(3));
      expect(PregnancyDateEngine.calculateTrimester(290), equals(3));
    });

    test(
      'calculateRemainingDays and isOverdue handle pre, on, and post EDD',
      () {
        final edd = DateTime(2026, 10, 8);

        // 10 days before EDD
        final nowBefore = DateTime(2026, 9, 28);
        expect(
          PregnancyDateEngine.calculateRemainingDays(edd: edd, now: nowBefore),
          equals(10),
        );
        expect(
          PregnancyDateEngine.isOverdue(edd: edd, now: nowBefore),
          isFalse,
        );

        // On EDD
        final nowOn = DateTime(2026, 10, 8);
        expect(
          PregnancyDateEngine.calculateRemainingDays(edd: edd, now: nowOn),
          equals(0),
        );
        expect(PregnancyDateEngine.isOverdue(edd: edd, now: nowOn), isFalse);

        // 3 days after EDD
        final nowAfter = DateTime(2026, 10, 11);
        expect(
          PregnancyDateEngine.calculateRemainingDays(edd: edd, now: nowAfter),
          equals(0),
        );
        expect(PregnancyDateEngine.isOverdue(edd: edd, now: nowAfter), isTrue);
      },
    );
  });
}
