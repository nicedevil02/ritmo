import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/utils/time_of_day_minutes.dart';

void main() {
  group('TimeOfDayMinutes Tests (CAL-03)', () {
    test('tryParse parses standard ASCII HH:mm', () {
      expect(TimeOfDayMinutes.tryParse('00:00'), 0);
      expect(TimeOfDayMinutes.tryParse('08:30'), 510);
      expect(TimeOfDayMinutes.tryParse('23:59'), 1439);
      expect(TimeOfDayMinutes.tryParse('7:05'), 425);
    });

    test('tryParse parses Persian and Arabic numerals', () {
      expect(TimeOfDayMinutes.tryParse('۰۸:۳۰'), 510);
      expect(TimeOfDayMinutes.tryParse('۲۳:۵۹'), 1439);
      expect(TimeOfDayMinutes.tryParse('٠٧:١٥'), 435);
    });

    test('tryParse returns null on invalid inputs without falling to 0', () {
      expect(TimeOfDayMinutes.tryParse(null), isNull);
      expect(TimeOfDayMinutes.tryParse(''), isNull);
      expect(TimeOfDayMinutes.tryParse('abc'), isNull);
      expect(TimeOfDayMinutes.tryParse('99:99'), isNull);
      expect(TimeOfDayMinutes.tryParse('24:00'), isNull);
      expect(TimeOfDayMinutes.tryParse('12:60'), isNull);
      expect(TimeOfDayMinutes.tryParse('-01:30'), isNull);
    });

    test('format converts minutes to HH:mm with padding', () {
      expect(TimeOfDayMinutes.format(0), '00:00');
      expect(TimeOfDayMinutes.format(510), '08:30');
      expect(TimeOfDayMinutes.format(1439), '23:59');
      // Clamping behavior
      expect(TimeOfDayMinutes.format(-10), '00:00');
      expect(TimeOfDayMinutes.format(2000), '23:59');
    });

    test('isValid returns true only for valid time strings', () {
      expect(TimeOfDayMinutes.isValid('08:30'), isTrue);
      expect(TimeOfDayMinutes.isValid('۰۸:۳۰'), isTrue);
      expect(TimeOfDayMinutes.isValid('abc'), isFalse);
      expect(TimeOfDayMinutes.isValid(null), isFalse);
    });
  });
}
