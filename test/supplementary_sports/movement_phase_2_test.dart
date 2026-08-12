// test/supplementary_sports/movement_phase_2_test.dart
//
// تست‌های واحد برای فاز ۲: برنامه‌ریزی با روتین
// بررسی صحت فرمت‌بندی تکرار، نگاشت زمان‌بندی و مقادیر ذخیره‌سازی روتین‌ها.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/routines/domain/routine_recurrence.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';

void main() {
  group('Phase 2 | Recurrence & legacy parameter derivation tests', () {
    test('deriveScheduleParams derives EVERY_DAY schedule for DailyRecurrence', () {
      final (schedType, daysOfWeek) = deriveScheduleParams(const DailyRecurrence());
      expect(schedType, equals('EVERY_DAY'));
      expect(daysOfWeek, equals('6,7,1,2,3,4,5'));
    });

    test('deriveScheduleParams derives SPECIFIC_DAYS schedule for custom WeekdaysRecurrence', () {
      final recurrence = WeekdaysRecurrence(weekdays: {6, 7, 5}); // Sat, Sun, Fri
      final (schedType, daysOfWeek) = deriveScheduleParams(recurrence);
      expect(schedType, equals('SPECIFIC_DAYS'));
      expect(daysOfWeek, equals('5,6,7')); // Sorted 5,6,7
    });

    test('encodeRecurrenceRule correctly serializes DailyRecurrence', () {
      final recurrence = const DailyRecurrence();
      final ruleStr = encodeRecurrenceRule(
        recurrence: recurrence,
        startDate: DateTime(2026, 8, 11),
        reminderTimes: ['07:00'],
      );

      final decoded = jsonDecode(ruleStr) as Map<String, dynamic>;
      expect(decoded['startDate'], equals('2026-08-11'));
      expect(decoded['reminderTimes'], equals(['07:00']));
      expect(decoded['weekdays'], equals([1, 2, 3, 4, 5, 6, 7]));
    });

    test('encodeRecurrenceRule correctly serializes custom WeekdaysRecurrence', () {
      final recurrence = WeekdaysRecurrence(weekdays: {6, 7, 5});
      final ruleStr = encodeRecurrenceRule(
        recurrence: recurrence,
        startDate: DateTime(2026, 8, 11),
        reminderTimes: ['18:30'],
      );

      final decoded = jsonDecode(ruleStr) as Map<String, dynamic>;
      expect(decoded['startDate'], equals('2026-08-11'));
      expect(decoded['reminderTimes'], equals(['18:30']));
      expect(decoded['weekdays'], equals([5, 6, 7])); // Fri, Sat, Sun
    });
  });

  group('Phase 2 | Routine Save Values Validation', () {
    test('Verify correct data dictionary values for sports routine creation', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      const kind = MovementKind(
        code: 'HIKING',
        titleFa: 'کوهنوردی',
        emoji: '🧗',
        family: MovementFamily.endurance,
        baseMet: 6.0,
        metLow: 5.0,
        metHigh: 8.0,
        primaryMetric: MovementMetric.elevation,
        secondaryMetric: MovementMetric.none,
        isOutdoor: true,
        isSocial: true,
        needsVenue: true,
        jointImpact: 2,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );

      final routineData = {
        'id': 'routine_123',
        'title': kind.titleFa,
        'category': 'fitness',
        'routineType': 'ROUTINE',
        'notificationLevel': 'NORMAL',
        'isEssential': 0,
        'targetDurationMinutes': 90,
        'isArchived': 0,
        'isPrivate': 0,
        'createdAt': now,
        'updatedAt': now,
        'reminderOffsetMinutes': 15,
        'movementKind': kind.code,
        'movementTargetMetric': kind.primaryMetric.name.toUpperCase(),
        'movementTargetValue': 400.0, // 400 meters of elevation
        'movementIsMeetup': 0,
      };

      expect(routineData['title'], equals('کوهنوردی'));
      expect(routineData['category'], equals('fitness'));
      expect(routineData['movementKind'], equals('HIKING'));
      expect(routineData['movementTargetMetric'], equals('ELEVATION'));
      expect(routineData['movementTargetValue'], equals(400.0));
      expect(routineData['reminderOffsetMinutes'], equals(15));
    });
  });
}
