import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_engine.dart';

void main() {
  group('DstSafeDateMath Tests (PRG-10)', () {
    test('dayShiftBetween calculates exact day count regardless of time components', () {
      final date1 = DateTime(2026, 3, 21, 23, 59, 59);
      final date2 = DateTime(2026, 3, 22, 0, 0, 1);
      expect(PregnancyDateEngine.dayShiftBetween(date1, date2), equals(1));
    });

    test('dayShiftBetween handles 280 days spanning across seasons accurately', () {
      final lmp = DateTime(2026, 1, 1, 12, 0);
      final edd = DateTime(2026, 10, 8, 8, 0);
      expect(PregnancyDateEngine.dayShiftBetween(lmp, edd), equals(280));
    });

    test('calculateCurrentGestation is DST-safe across transition windows', () {
      final lmp = DateTime(2026, 3, 20, 23, 0);
      final now = DateTime(2026, 3, 23, 1, 0); // 3 calendar days later
      final ga = PregnancyDateEngine.calculateCurrentGestation(lmp: lmp, now: now);

      expect(ga.totalDays, equals(3));
      expect(ga.weeks, equals(0));
      expect(ga.days, equals(3));
    });

    test('calculateRemainingDays is DST-safe across arbitrary times of day', () {
      final edd = DateTime(2026, 10, 8, 0, 0);
      final now = DateTime(2026, 10, 1, 23, 45); // 7 calendar days before
      final remaining = PregnancyDateEngine.calculateRemainingDays(edd: edd, now: now);

      expect(remaining, equals(7));
    });
  });
}
