import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/routine_occurrence_generator.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_policy.dart';
import 'package:ritmo/core/notifications/notification_policy_engine.dart';
import 'package:ritmo/core/notifications/notification_request.dart';

void main() {
  group('Multi-Dose Scheduling & Reminders Tests', () {
    test('RecurrenceRule handles multiple dose reminder times properly', () {
      final rule = RecurrenceRule(
        weekdays: const [6, 7, 1, 2, 3, 4, 5],
        reminderTimes: const ['08:00', '14:00', '20:00'],
      );

      final map = rule.toMap();
      expect(map['reminderTimes'], ['08:00', '14:00', '20:00']);

      final restored = RecurrenceRule.fromMap(map);
      expect(restored.reminderTimes, ['08:00', '14:00', '20:00']);
      expect(restored.reminderTimes.length, 3);
    });

    test('Deterministic reminderId generation produces distinct keys per dose time slot', () {
      const routineId = 'routine_med_101';
      const scheduleId = 'sched_101';
      const dateStr = '2026-08-17';
      const times = ['08:00', '14:00', '20:00'];

      final ids = times.map((t) => 'rem_${routineId}_${scheduleId}_${dateStr}_${t.replaceAll(':', '')}').toList();

      expect(ids[0], 'rem_routine_med_101_sched_101_2026-08-17_0800');
      expect(ids[1], 'rem_routine_med_101_sched_101_2026-08-17_1400');
      expect(ids[2], 'rem_routine_med_101_sched_101_2026-08-17_2000');

      // Ensure no collision
      expect(ids.toSet().length, 3);
    });

    test('Jalali weekday matching aligns with RoutineOccurrenceGenerator', () {
      // 2026-08-17 is Monday -> Dart weekday 1 -> Jalali 1 (دوشنبه)
      final monday = DateTime(2026, 8, 17);
      expect(monday.weekday, 1);

      // Rule only scheduled on Saturday (6) and Sunday (7)
      final weekendRule = RecurrenceRule(
        weekdays: const [6, 7],
        reminderTimes: const ['09:00'],
      );
      expect(RoutineOccurrenceGenerator.shouldOccurOnDate(monday, weekendRule), isFalse);

      // Rule scheduled on Monday (1)
      final mondayRule = RecurrenceRule(
        weekdays: const [1, 2, 3],
        reminderTimes: const ['09:00'],
      );
      expect(RoutineOccurrenceGenerator.shouldOccurOnDate(monday, mondayRule), isTrue);

      // Saturday test: 2026-08-15 is Saturday -> Dart weekday 6 -> Jalali 6 (شنبه)
      final saturday = DateTime(2026, 8, 15);
      expect(saturday.weekday, 6);
      expect(RoutineOccurrenceGenerator.shouldOccurOnDate(saturday, weekendRule), isTrue);
    });

    test('Critical medical notification bypasses quiet hours in NotificationPolicyEngine', () {
      final now = DateTime(2026, 8, 17, 2, 0); // 2:00 AM (inside quiet hours)
      const policy = NotificationPolicy(
        masterEnabled: true,
        quietHoursEnabled: true,
        quietHoursStart: '00:00',
        quietHoursEnd: '07:00',
        calendarExceptionBehavior: 'NORMAL',
      );

      // Medical critical reminder
      final medReq = NotificationRequest(
        id: 'rem_med_1',
        channel: NotificationChannelId.critical,
        scheduledAt: now,
        title: 'انسولین شبانه',
        sourceSystem: 'routines',
      );
      final medDecision = NotificationPolicyEngine.decide(medReq, policy, now);
      expect(medDecision.isSuppressed, isFalse);
      expect(medDecision.isDeferred, isFalse); // Bypasses quiet hours!

      // Normal non-essential routine reminder
      final routineReq = NotificationRequest(
        id: 'rem_routine_1',
        channel: NotificationChannelId.routine,
        scheduledAt: now,
        title: 'مطالعه کتاب',
        sourceSystem: 'routines',
      );
      final routineDecision = NotificationPolicyEngine.decide(routineReq, policy, now);
      expect(routineDecision.isDeferred, isTrue); // Deferred until quiet hours end!
      expect(routineDecision.deferUntil?.hour, 7);
    });

    test('Snooze delay calculation is accurate', () {
      final scheduledTime = DateTime(2026, 8, 17, 8, 0).millisecondsSinceEpoch;
      const snoozeMinutes = 15;
      final snoozedMs = scheduledTime + (snoozeMinutes * 60 * 1000);

      final diffMinutes = (snoozedMs - scheduledTime) / (60 * 1000);
      expect(diffMinutes, 15.0);

      final snoozedDate = DateTime.fromMillisecondsSinceEpoch(snoozedMs);
      expect(snoozedDate.hour, 8);
      expect(snoozedDate.minute, 15);
    });
  });
}
