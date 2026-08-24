import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/features/routines/domain/strategies/planner_save_context.dart';
import 'package:ritmo/features/routines/presentation/planner_controller.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Private Reminders & Confidential Notification Tests', () {
    test('1. PlannerController defaults isPrivate to false and toggles correctly', () {
      final controller = PlannerController(
        onSaved: () {},
        onPageChanged: (_) {},
      );

      expect(controller.isPrivate, isFalse);

      controller.isPrivate = true;
      expect(controller.isPrivate, isTrue);
    });

    test('2. PlannerSaveContext encapsulates isPrivate properly', () {
      final ctx = PlannerSaveContext(
        title: 'جلسه محرمانه کاری',
        description: '',
        notes: '',
        selectedDate: DateTime.now(),
        selectedTime: const TimeOfDay(hour: 14, minute: 30),
        isEditing: false,
        routineToEdit: null,
        selectedCategory: Category.work,
        itemType: 'EVENT',
        recurrenceType: 'ONCE',
        targetDuration: 60,
        reminderOffsetMinutes: 15,
        priority: 1.5,
        energyRule: 'NONE',
        isPrivate: true,
        dependsOnRoutineId: null,
        selectedZoneId: null,
        worshipType: 'MUSTAHAB',
        worshipDebtType: 'PRAYER',
        worshipTotalCount: 1,
        worshipDailyTarget: 1,
        worshipReminderAnchor: 'NONE',
        worshipOffsetMinutes: 0,
        worshipSelectedDays: const [],
        worshipRepeatType: 'ONCE',
        sportsOpType: 'ROUTINE',
        sportsType: 'RUNNING',
        sportsDuration: 30,
        sportsIntensity: 'MEDIUM',
        sportsLocation: 'GYM',
        sportsFeeling: '',
        medicalMode: 'FIXED',
        medicalTimes: const [],
        medicalStockCount: 0,
        medicalRefillWarning: 0,
        medicalMinIntervalHours: 0,
        medicalMaxDosesPerDay: 0,
        courseType: 'VIDEO',
        courseTotalSessions: 0,
        courseWeeklyTarget: 0,
        courseSessionDuration: 0,
        coursePreferredDays: const [],
        coursePreferredTime: const TimeOfDay(hour: 0, minute: 0),
        goalType: 'DAILY',
        goalTargetDate: DateTime.now(),
        goalSteps: const [],
        reflectionMood: 3,
        reflectionWins: '',
        reflectionGratitude: '',
        reflectionLearnings: '',
        reflectionIsPrivate: false,
      );

      expect(ctx.isPrivate, isTrue);
      expect(ctx.title, 'جلسه محرمانه کاری');
    });

    test('3. Private NotificationRequest requires non-empty redactedTitle', () {
      final req = NotificationRequest(
        id: 'rem_private_1',
        channel: NotificationChannelId.routine,
        scheduledAt: DateTime.now().add(const Duration(minutes: 30)),
        title: '🔒 یادآوری محرمانه',
        privacy: NotificationPrivacy.locked,
        redactedTitle: '🔒 یادآوری محرمانه',
        redactedBody: 'جهت مشاهده جزئیات ضربه بزنید و هویت خود را تأیید کنید.',
        sourceSystem: 'routines',
      );

      expect(req.privacy, NotificationPrivacy.locked);
      expect(req.privacy.requiresRedaction, isTrue);
      expect(req.redactedTitle, '🔒 یادآوری محرمانه');
    });
  });
}
