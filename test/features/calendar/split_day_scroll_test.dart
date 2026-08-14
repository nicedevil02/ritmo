import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/calendar/presentation/logic/split_day_scroll_helper.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_tokens.dart';

void main() {
  group('P0-8: Split Day Scroll Math Tests', () {
    test('00:00 maps to column 0, offset 0.0', () {
      final target = splitDayScrollTargetFor(0);
      expect(target.columnIndex, equals(0));
      expect(target.offset, equals(0.0));
    });

    test('09:05 (545 min) maps to column 0, offset (545 - 60) * 1.6 = 776.0', () {
      final target = splitDayScrollTargetFor(545);
      expect(target.columnIndex, equals(0));
      expect(target.offset, closeTo((545 - 60) * CalendarTokens.pxPerMinuteSplit, 0.001));
    });

    test('11:59 (719 min) maps to column 0, offset (719 - 60) * 1.6 = 1054.4', () {
      final target = splitDayScrollTargetFor(719);
      expect(target.columnIndex, equals(0));
      expect(target.offset, closeTo((719 - 60) * CalendarTokens.pxPerMinuteSplit, 0.001));
    });

    test('12:00 (720 min) maps to column 1, offset 0.0', () {
      final target = splitDayScrollTargetFor(720);
      expect(target.columnIndex, equals(1));
      expect(target.offset, equals(0.0));
    });

    test('14:00 (840 min) maps to column 1, minute in column 120, offset (120 - 60) * 1.6 = 96.0', () {
      final target = splitDayScrollTargetFor(840);
      expect(target.columnIndex, equals(1));
      expect(target.offset, closeTo((120 - 60) * CalendarTokens.pxPerMinuteSplit, 0.001));
    });

    test('23:59 (1439 min) maps to column 1, minute in column 719, offset (719 - 60) * 1.6 = 1054.4', () {
      final target = splitDayScrollTargetFor(1439);
      expect(target.columnIndex, equals(1));
      expect(target.offset, closeTo((719 - 60) * CalendarTokens.pxPerMinuteSplit, 0.001));
    });
  });
}
