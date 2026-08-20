// test/supplementary_sports/movement_suggester_and_override_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/features/routines/domain/routine_recurrence.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_budget.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_suggester.dart';

void main() {
  group('MovementMetric & TargetValue Tests', () {
    test('defaultTargetValue returns correct metric-specific defaults', () {
      const running = MovementKind(
        code: 'RUNNING',
        titleFa: 'دویدن',
        emoji: '🏃',
        family: MovementFamily.endurance,
        baseMet: 8.0,
        metLow: 6.0,
        metHigh: 10.0,
        primaryMetric: MovementMetric.distance,
        secondaryMetric: MovementMetric.none,
        isOutdoor: true,
        isSocial: false,
        needsVenue: false,
        jointImpact: 3,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );
      expect(running.defaultTargetValue(), equals(5.0));

      const cycling = MovementKind(
        code: 'CYCLING',
        titleFa: 'دوچرخه‌سواری',
        emoji: '🚴',
        family: MovementFamily.endurance,
        baseMet: 7.0,
        metLow: 5.0,
        metHigh: 9.0,
        primaryMetric: MovementMetric.distance,
        secondaryMetric: MovementMetric.none,
        isOutdoor: true,
        isSocial: false,
        needsVenue: false,
        jointImpact: 1,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );
      expect(cycling.defaultTargetValue(), equals(10.0));

      const swimming = MovementKind(
        code: 'SWIMMING',
        titleFa: 'شنا',
        emoji: '🏊',
        family: MovementFamily.endurance,
        baseMet: 7.0,
        metLow: 5.0,
        metHigh: 9.0,
        primaryMetric: MovementMetric.laps,
        secondaryMetric: MovementMetric.none,
        isOutdoor: false,
        isSocial: false,
        needsVenue: true,
        jointImpact: 0,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );
      expect(swimming.defaultTargetValue(), equals(10.0));

      const hiking = MovementKind(
        code: 'HIKING',
        titleFa: 'کوهنوردی',
        emoji: '🏔',
        family: MovementFamily.outdoor,
        baseMet: 6.0,
        metLow: 4.0,
        metHigh: 8.0,
        primaryMetric: MovementMetric.elevation,
        secondaryMetric: MovementMetric.none,
        isOutdoor: true,
        isSocial: false,
        needsVenue: false,
        jointImpact: 2,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );
      expect(hiking.defaultTargetValue(), equals(100.0));

      const walking = MovementKind(
        code: 'WALKING',
        titleFa: 'پیاده‌روی',
        emoji: '🚶',
        family: MovementFamily.endurance,
        baseMet: 3.5,
        metLow: 2.5,
        metHigh: 4.5,
        primaryMetric: MovementMetric.duration,
        secondaryMetric: MovementMetric.none,
        isOutdoor: true,
        isSocial: false,
        needsVenue: false,
        jointImpact: 1,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );
      expect(walking.defaultTargetValue(durationMinutes: 45), equals(45.0));
    });
  });

  group('RETIME Multi-Day Schedule Isolation Logic Tests', () {
    test('Splitting multi-day schedule on RETIME preserves original day and creates isolated day', () {
      const routineId = 'routine_running_01';
      final originalDays = [6, 1]; // Saturday (6) and Monday (1)
      const originalTime = '18:30';
      const targetDartWeekday = 6; // Retiming Saturday only
      const newTime = '20:15';

      // 1. Verify target day is part of schedule
      expect(originalDays.contains(targetDartWeekday), isTrue);

      // 2. Remove target day to form remaining schedule
      final remainingDays = List<int>.from(originalDays)..remove(targetDartWeekday);
      remainingDays.sort();
      expect(remainingDays, equals([1])); // Only Monday remaining

      final remainingRecurrence = WeekdaysRecurrence(weekdays: remainingDays.toSet());
      final (remSchedType, remDaysOfWeek) = deriveScheduleParams(remainingRecurrence);
      expect(remSchedType, equals('SPECIFIC_DAYS'));
      expect(remDaysOfWeek, equals('1'));

      final remainingRecurrenceJson = encodeRecurrenceRule(
        recurrence: remainingRecurrence,
        startDate: DateTime(2026, 8, 1),
        reminderTimes: [originalTime],
      );
      final decodedRemaining = jsonDecode(remainingRecurrenceJson) as Map<String, dynamic>;
      expect(decodedRemaining['weekdays'], equals([1]));
      expect(decodedRemaining['reminderTimes'], equals(['18:30']));

      // 3. Form new schedule specifically for Saturday
      final newRecurrence = WeekdaysRecurrence(weekdays: {targetDartWeekday});
      final (newSchedType, newDaysOfWeek) = deriveScheduleParams(newRecurrence);
      expect(newSchedType, equals('SPECIFIC_DAYS'));
      expect(newDaysOfWeek, equals('6'));

      final newRecurrenceJson = encodeRecurrenceRule(
        recurrence: newRecurrence,
        startDate: DateTime(2026, 8, 1),
        reminderTimes: [newTime],
      );
      final decodedNew = jsonDecode(newRecurrenceJson) as Map<String, dynamic>;
      expect(decodedNew['weekdays'], equals([6]));
      expect(decodedNew['reminderTimes'], equals(['20:15']));
    });
  });

  group('MovementSuggester Scoring & Safety Tests', () {
    const budgetSnapshot = MovementBudgetSnapshot(
      weeklyMetMinutesTarget: 500,
      achievedMetMinutes: 200,
      activeDays: 1,
      targetActiveDays: 4,
      byFamily: {},
      byKind: {},
      daysRemaining: 5,
      projectedTotal: 400,
      events: [],
      kindsByCode: {},
    );

    const highImpactRunning = MovementKind(
      code: 'RUNNING',
      titleFa: 'دویدن',
      emoji: '🏃',
      family: MovementFamily.endurance,
      baseMet: 8.0,
      metLow: 6.0,
      metHigh: 10.0,
      primaryMetric: MovementMetric.distance,
      secondaryMetric: MovementMetric.none,
      isOutdoor: true,
      isSocial: false,
      needsVenue: false,
      jointImpact: 3,
      isCustom: false,
      isEnabled: true,
      usageCount: 0,
      sortOrder: 0,
    );

    const lowImpactSwimming = MovementKind(
      code: 'SWIMMING',
      titleFa: 'شنا',
      emoji: '🏊',
      family: MovementFamily.endurance,
      baseMet: 7.0,
      metLow: 5.0,
      metHigh: 9.0,
      primaryMetric: MovementMetric.laps,
      secondaryMetric: MovementMetric.none,
      isOutdoor: false,
      isSocial: false,
      needsVenue: true,
      jointImpact: 0,
      isCustom: false,
      isEnabled: true,
      usageCount: 0,
      sortOrder: 0,
    );

    const gentleYoga = MovementKind(
      code: 'YOGA',
      titleFa: 'یوگا',
      emoji: '🧘',
      family: MovementFamily.mindBody,
      baseMet: 3.0,
      metLow: 2.0,
      metHigh: 4.0,
      primaryMetric: MovementMetric.duration,
      secondaryMetric: MovementMetric.none,
      isOutdoor: false,
      isSocial: false,
      needsVenue: false,
      jointImpact: 0,
      isCustom: false,
      isEnabled: true,
      usageCount: 0,
      sortOrder: 0,
    );

    test('Safety veto: knee limitation returns negative infinity for high joint impact', () {
      const ctxWithKneeIssue = SuggestionCtx(
        budget: budgetSnapshot,
        availableMinutes: 30,
        energy: 4,
        soreness: 1,
        painLevel: 0,
        limitations: {'knee'},
        recentKindCodes14d: {},
        jalaliMonth: 5,
      );

      final scoreRunning = scoreMovementKind(highImpactRunning, ctxWithKneeIssue);
      expect(scoreRunning, equals(double.negativeInfinity));

      final scoreSwimming = scoreMovementKind(lowImpactSwimming, ctxWithKneeIssue);
      expect(scoreSwimming.isFinite, isTrue);
      expect(scoreSwimming, greaterThan(0));
    });

    test('Acute fatigue/soreness: favors gentle recovery movements', () {
      const fatiguedCtx = SuggestionCtx(
        budget: budgetSnapshot,
        availableMinutes: 30,
        energy: 1, // Low energy
        soreness: 5, // High soreness
        painLevel: 1,
        limitations: {},
        recentKindCodes14d: {},
        jalaliMonth: 5,
      );

      final yogaFit = readinessFit(gentleYoga, fatiguedCtx);
      final runningFit = readinessFit(highImpactRunning, fatiguedCtx);

      expect(yogaFit, greaterThan(runningFit));
      expect(yogaFit, equals(1.0));
      expect(runningFit, equals(0.0));
    });
  });
}
