import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/health/data/pregnancy_helpers.dart';

void main() {
  group('UX-03 Human Countdown & Jalali Month Tests', () {
    test('formatHumanCountdown returns correct Persian strings for boundary days', () {
      expect(PregnancyHelpers.formatHumanCountdown(123), contains('۱۷ هفته و ۴ روز دیگر'));
      expect(PregnancyHelpers.formatHumanCountdown(14), contains('۲ هفته دیگر'));
      expect(PregnancyHelpers.formatHumanCountdown(5), contains('۵ روز دیگر'));
      expect(PregnancyHelpers.formatHumanCountdown(0), contains('امروز روز تخمینی زایمان است'));
      expect(PregnancyHelpers.formatHumanCountdown(-3), equals('از تاریخ تقریبی گذشته است'));
    });

    test('approxJalaliMonth returns correct month prefix based on day', () {
      final earlyDate = DateTime(2026, 8, 2); // Early in Jalali month
      final midDate = DateTime(2026, 8, 12); // Mid in Jalali month
      final lateDate = DateTime(2026, 8, 22); // Late in Jalali month

      expect(PregnancyHelpers.approxJalaliMonth(earlyDate), contains('حدوداً'));
      expect(PregnancyHelpers.approxJalaliMonth(midDate), contains('حدوداً'));
      expect(PregnancyHelpers.approxJalaliMonth(lateDate), contains('حدوداً'));
    });
  });
}
