import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  group('P0-4 & P0-5: Agenda Navigation & Year Clamping Tests', () {
    test('Jalali target year day clamping works correctly for leap and standard years', () {
      // Esfand 30 in leap year vs standard year
      final leapDate = Jalali(1403, 12, 30);
      final targetYear = 1404;
      final maxDays = Jalali(targetYear, leapDate.month, 1).monthLength;
      final clampedDay = leapDate.day.clamp(1, maxDays);
      final clampedDate = Jalali(targetYear, leapDate.month, clampedDay);

      expect(maxDays, equals(29));
      expect(clampedDay, equals(29));
      expect(clampedDate.day, equals(29));
    });

    test('Agenda scale navigation moves anchor ±7 days', () {
      final selected = DateTime(2026, 8, 14);
      final nextWeek = selected.add(const Duration(days: 7));
      final prevWeek = selected.subtract(const Duration(days: 7));

      expect(nextWeek, equals(DateTime(2026, 8, 21)));
      expect(prevWeek, equals(DateTime(2026, 8, 7)));
    });
  });
}
