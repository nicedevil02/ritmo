import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/routines/domain/strategies/planner_save_context.dart';
import 'package:ritmo/features/routines/presentation/planner_controller.dart';
import 'package:ritmo/features/routines/presentation/widgets/routine_type_picker.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Routine Types & Architecture Tests', () {
    test('RoutineType enum contains all 6 models', () {
      expect(RoutineType.values.length, 6);
      expect(RoutineType.values, contains(RoutineType.timeBased));
      expect(RoutineType.values, contains(RoutineType.countBased));
      expect(RoutineType.values, contains(RoutineType.progressive));
      expect(RoutineType.values, contains(RoutineType.intervalBased));
      expect(RoutineType.values, contains(RoutineType.dependent));
      expect(RoutineType.values, contains(RoutineType.asNeeded));
    });

    test('RoutineTypePicker options contain 6 full descriptors', () {
      expect(RoutineTypePicker.options.length, 6);
      final types = RoutineTypePicker.options.map((o) => o.type).toList();
      expect(types, containsAll([
        RoutineType.timeBased,
        RoutineType.countBased,
        RoutineType.progressive,
        RoutineType.intervalBased,
        RoutineType.dependent,
        RoutineType.asNeeded,
      ]));
    });

    test('PlannerController updates and holds routineType configuration state', () {
      final controller = PlannerController(
        onSaved: () {},
        onPageChanged: (_) {},
      );

      expect(controller.routineType, RoutineType.timeBased);

      // Set to countBased
      controller.setRoutineType(RoutineType.countBased);
      controller.countTarget = 12;
      controller.countUnit = 'لیوان';

      expect(controller.routineType, RoutineType.countBased);
      expect(controller.countTarget, 12);
      expect(controller.countUnit, 'لیوان');

      // Set to progressive
      controller.setRoutineType(RoutineType.progressive);
      controller.progressionStart = 10;
      controller.progressionStep = 5;
      controller.progressionTarget = 60;
      controller.progressionEveryN = 7;

      expect(controller.routineType, RoutineType.progressive);
      expect(controller.progressionStart, 10);
      expect(controller.progressionStep, 5);
      expect(controller.progressionTarget, 60);

      // Set to intervalBased
      controller.setRoutineType(RoutineType.intervalBased);
      controller.minIntervalHours = 6;
      controller.maxDosesPerDay = 3;

      expect(controller.routineType, RoutineType.intervalBased);
      expect(controller.minIntervalHours, 6);
      expect(controller.maxDosesPerDay, 3);
    });

    test('PlannerSaveContext holds all routineType behavioral fields', () {
      final now = DateTime.now();
      final ctx = PlannerSaveContext(
        title: 'نوشیدن آب روزانه',
        description: '۸ لیوان',
        notes: '',
        selectedDate: now,
        selectedTime: const TimeOfDay(hour: 8, minute: 0),
        isEditing: false,
        routineToEdit: null,
        selectedCategory: Category.personal,
        itemType: 'ROUTINE',
        routineType: RoutineType.countBased,
        countTarget: 8,
        countUnit: 'لیوان',
        progressionStart: 5,
        progressionStep: 2,
        progressionTarget: 30,
        progressionEveryN: 7,
        dependencyType: DependencyType.afterCompletion,
        dependencyOffsetMinutes: 0,
        recurrenceType: 'EVERY_DAY',
        targetDuration: 15,
        reminderOffsetMinutes: 0,
        priority: 1.0,
        energyRule: 'NONE',
        dependsOnRoutineId: null,
        selectedZoneId: null,
        worshipType: 'MUSTAHAB',
        worshipDebtType: 'PRAYER',
        worshipTotalCount: 10,
        worshipDailyTarget: 1,
        worshipReminderAnchor: 'NONE',
        worshipOffsetMinutes: 0,
        worshipSelectedDays: const [1, 2, 3, 4, 5, 6, 7],
        worshipRepeatType: 'RECURRING',
        sportsOpType: 'ROUTINE',
        sportsType: 'STRENGTH',
        sportsDuration: 45,
        sportsIntensity: 'MEDIUM',
        sportsLocation: 'GYM',
        sportsFeeling: 'خوب',
        medicalMode: 'FIXED',
        medicalTimes: const [],
        medicalStockCount: 30,
        medicalRefillWarning: 5,
        medicalMinIntervalHours: 4,
        medicalMaxDosesPerDay: 4,
        courseType: 'VIDEO',
        courseTotalSessions: 10,
        courseWeeklyTarget: 3,
        courseSessionDuration: 45,
        coursePreferredDays: const [],
        coursePreferredTime: const TimeOfDay(hour: 18, minute: 0),
        goalType: 'DAILY',
        goalTargetDate: now,
        goalSteps: const [],
        reflectionMood: 3,
        reflectionWins: '',
        reflectionGratitude: '',
        reflectionLearnings: '',
        reflectionIsPrivate: false,
      );

      expect(ctx.routineType, RoutineType.countBased);
      expect(ctx.countTarget, 8);
      expect(ctx.countUnit, 'لیوان');
    });
  });
}
