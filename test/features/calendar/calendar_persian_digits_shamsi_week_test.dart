import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/utils/shamsi_week.dart';
import 'package:ritmo/features/calendar/presentation/logic/agenda_bucketing.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-36: Persian Digits & Shamsi Weekday Standardization', () {
    test('daySubGroupLabel output contains only Persian digits (zero Latin digits)', () {
      final label = daySubGroupLabel('2026-08-18');

      expect(RegExp(r'[0-9]').hasMatch(label), isFalse,
          reason: 'daySubGroupLabel "$label" must not contain Latin ASCII digits');
      expect(label, contains('مرداد'));
      expect(label, contains('سه‌شنبه'));
    });

    test('ShamsiWeek produces correct names and plurals for all 7 days', () {
      final expectedNames = [
        'شنبه',
        'یک‌شنبه',
        'دوشنبه',
        'سه‌شنبه',
        'چهارشنبه',
        'پنج‌شنبه',
        'جمعه',
      ];
      final expectedPlurals = [
        'شنبه‌ها',
        'یک‌شنبه‌ها',
        'دوشنبه‌ها',
        'سه‌شنبه‌ها',
        'چهارشنبه‌ها',
        'پنج‌شنبه‌ها',
        'جمعه‌ها',
      ];

      for (var wd = 1; wd <= 7; wd++) {
        expect(ShamsiWeek.nameOf(wd), equals(expectedNames[wd - 1]));
        expect(ShamsiWeek.pluralOf(wd), equals(expectedPlurals[wd - 1]));
      }
    });

    test('calculateRecurrenceLabel for single recurring weekday uses ShamsiWeek.pluralOf', () {
      // 3 consecutive Saturdays: 1405-05-24, 1405-05-31, 1405-06-07
      final sat1 = Jalali(1405, 5, 24).toDateTime();
      final sat2 = Jalali(1405, 5, 31).toDateTime();
      final sat3 = Jalali(1405, 6, 7).toDateTime();

      final label = calculateRecurrenceLabel([sat1, sat2, sat3], 21);

      expect(label, equals('شنبه‌ها'));
    });
  });
}
