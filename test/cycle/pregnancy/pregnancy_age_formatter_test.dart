import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_engine.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';

void main() {
  group('PregnancyAgeFormatter Tests (PRG-09)', () {
    test('formatGestationalAgeFa produces "هفته ۲۱" when days is 0', () {
      const age = GestationalAge(weeks: 21, days: 0, totalDays: 147);
      final text = PregnancyDateEngine.formatGestationalAgeFa(age);
      expect(text, equals('هفته ۲۱'));
    });

    test('formatGestationalAgeFa produces "هفته ۲۱ و ۳ روز" when days > 0', () {
      const age = GestationalAge(weeks: 21, days: 3, totalDays: 150);
      final text = PregnancyDateEngine.formatGestationalAgeFa(age);
      expect(text, equals('هفته ۲۱ و ۳ روز'));
    });

    test(
      'formatGestationalAgeFa produces month and week when unit is months',
      () {
        const age = GestationalAge(weeks: 21, days: 0, totalDays: 147);
        final text = PregnancyDateEngine.formatGestationalAgeFa(
          age,
          unit: PregnancyAgeUnit.months,
        );
        expect(text, equals('ماه ۵ (هفته ۲۱)'));
      },
    );

    test(
      'formatRemainingTimeFa handles negative, zero, days-only, weeks-only, and combined',
      () {
        // Overdue
        expect(
          PregnancyDateEngine.formatRemainingTimeFa(-3),
          equals('از موعد گذشته'),
        );

        // Due day
        expect(
          PregnancyDateEngine.formatRemainingTimeFa(0),
          equals('امروز روز موعد است'),
        );

        // Days only (< 7 days)
        expect(
          PregnancyDateEngine.formatRemainingTimeFa(5),
          equals('۵ روز تا زایمان'),
        );

        // Weeks only (exact multiple of 7)
        expect(
          PregnancyDateEngine.formatRemainingTimeFa(14),
          equals('۲ هفته تا زایمان'),
        );

        // Combined weeks and days
        expect(
          PregnancyDateEngine.formatRemainingTimeFa(88),
          equals('۱۲ هفته و ۴ روز تا زایمان'),
        );
      },
    );
  });
}
