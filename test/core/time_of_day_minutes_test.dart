import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/utils/time_of_day_minutes.dart';

void main() {
  group('CAL-59: TimeOfDayMinutes Comprehensive Invariant Tests', () {
    test('1. tryParse parses standard ASCII HH:mm (CAL-03)', () {
      expect(TimeOfDayMinutes.tryParse('00:00'), equals(0));
      expect(TimeOfDayMinutes.tryParse('08:30'), equals(510));
      expect(TimeOfDayMinutes.tryParse('09:30'), equals(570));
      expect(TimeOfDayMinutes.tryParse('9:30'), equals(570));
      expect(TimeOfDayMinutes.tryParse('23:59'), equals(1439));
      expect(TimeOfDayMinutes.tryParse('7:05'), equals(425));
    });

    test('2. tryParse parses Persian and Arabic numerals (CAL-03)', () {
      expect(TimeOfDayMinutes.tryParse('۰۸:۳۰'), equals(510));
      expect(TimeOfDayMinutes.tryParse('۰۹:۳۰'), equals(570));
      expect(TimeOfDayMinutes.tryParse('۲۳:۵۹'), equals(1439));
      expect(TimeOfDayMinutes.tryParse('٠٧:١٥'), equals(435));
    });

    test('3. tryParse returns null on invalid inputs without falling to 0 (CAL-03)', () {
      expect(TimeOfDayMinutes.tryParse(null), isNull);
      expect(TimeOfDayMinutes.tryParse(''), isNull);
      expect(TimeOfDayMinutes.tryParse('abc'), isNull);
      expect(TimeOfDayMinutes.tryParse('99:99'), isNull);
      expect(TimeOfDayMinutes.tryParse('24:00'), isNull);
      expect(TimeOfDayMinutes.tryParse('12:60'), isNull);
      expect(TimeOfDayMinutes.tryParse('-01:30'), isNull);
      expect(TimeOfDayMinutes.tryParse('25:10'), isNull);
    });

    test('4. format converts minutes to HH:mm with padding and clamps (CAL-03)', () {
      expect(TimeOfDayMinutes.format(0), equals('00:00'));
      expect(TimeOfDayMinutes.format(510), equals('08:30'));
      expect(TimeOfDayMinutes.format(1439), equals('23:59'));
      // Clamping behavior
      expect(TimeOfDayMinutes.format(-5), equals('00:00'));
      expect(TimeOfDayMinutes.format(-10), equals('00:00'));
      expect(TimeOfDayMinutes.format(2000), equals('23:59'));
    });

    test('5. isValid returns true only for valid time strings', () {
      expect(TimeOfDayMinutes.isValid('08:30'), isTrue);
      expect(TimeOfDayMinutes.isValid('۰۹:۳۰'), isTrue);
      expect(TimeOfDayMinutes.isValid('abc'), isFalse);
      expect(TimeOfDayMinutes.isValid('24:00'), isFalse);
      expect(TimeOfDayMinutes.isValid(null), isFalse);
    });
  });
}
