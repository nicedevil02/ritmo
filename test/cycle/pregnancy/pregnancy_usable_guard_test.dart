import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';

void main() {
  group('PregnancyUsableGuard Tests (PRG-05)', () {
    test('isPregnancyUsable returns false when flag is true but dates are empty', () {
      final settings = {
        'cycle_pregnancy_mode': 'true',
      };
      expect(PregnancySettings.hasValidDates(settings), isFalse);
      expect(PregnancySettings.isPregnancyUsable(settings), isFalse);
    });

    test('isPregnancyUsable returns false when only start date is provided', () {
      final settings = {
        'cycle_pregnancy_mode': 'true',
        'preg_start_date': '2026-01-01',
      };
      expect(PregnancySettings.hasValidDates(settings), isFalse);
      expect(PregnancySettings.isPregnancyUsable(settings), isFalse);
    });

    test('hasValidDates returns false when difference is less than 200 days', () {
      final settings = {
        'cycle_pregnancy_mode': 'true',
        'preg_start_date': '2026-01-01',
        'preg_due_date': '2026-06-01', // ~151 days
      };
      expect(PregnancySettings.hasValidDates(settings), isFalse);
      expect(PregnancySettings.isPregnancyUsable(settings), isFalse);
    });

    test('hasValidDates returns false when difference is more than 320 days', () {
      final settings = {
        'cycle_pregnancy_mode': 'true',
        'preg_start_date': '2026-01-01',
        'preg_due_date': '2027-01-01', // 365 days
      };
      expect(PregnancySettings.hasValidDates(settings), isFalse);
      expect(PregnancySettings.isPregnancyUsable(settings), isFalse);
    });

    test('hasValidDates returns true when difference is 280 days, but isPregnancyUsable is false if mode is disabled', () {
      final settings = {
        'cycle_pregnancy_mode': 'false',
        'preg_start_date': '2026-01-01',
        'preg_due_date': '2026-10-08', // exactly 280 days
      };
      expect(PregnancySettings.hasValidDates(settings), isTrue);
      expect(PregnancySettings.isPregnancyUsable(settings), isFalse);
    });

    test('isPregnancyUsable returns true when mode is enabled and dates are valid', () {
      final settings = {
        'cycle_pregnancy_mode': 'true',
        'preg_start_date': '2026-01-01',
        'preg_due_date': '2026-10-08', // 280 days
      };
      expect(PregnancySettings.hasValidDates(settings), isTrue);
      expect(PregnancySettings.isPregnancyUsable(settings), isTrue);
    });
  });
}
