import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/application/mv_hub_controller.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Golden Path Phase A (Sprint 0) Full Integration E2E Test (S0-T8)', () {
    const profileEngine = ProfileEngine();
    const planEngine = PlanEngine();
    const budgetEngine = BudgetEngine();
    const insightEngine = InsightEngine();

    test('Full Lifecycle: Profile -> Plan -> Workout -> Feedback -> Budget -> BodyMap -> Streak', () async {
      // 1. Create User Profile
      final profile = profileEngine.createQuickProfile(
        daysPerWeek: 3,
        sessionDuration: 'medium',
        trainingLocation: 'home',
      ).value;

      expect(profile.daysPerWeek, equals(3));
      expect(profile.trainingDays.length, equals(3));

      // 2. Generate Plan for current week
      final currentSaturday = MvCalendar.getWeekSaturday(DateTime(2026, 8, 25)); // 2026-08-25
      final planDecision = planEngine.generateWeekPlan(
        profile: profile,
        weekSaturday: currentSaturday,
      );

      final weekSlots = planDecision.value;
      expect(weekSlots.length, equals(7));
      final trainingSlots = weekSlots.where((s) => s.slotType != MvSlotType.rest).toList();
      expect(trainingSlots.length, equals(3));

      // 3. Start and Finish a workout session with lossless feedback
      final activeSlot = trainingSlots.first;
      final startMs = currentSaturday.add(const Duration(hours: 9)).millisecondsSinceEpoch;
      final endMs = startMs + (30 * 60 * 1000); // 30 minutes

      final session = MvSession(
        id: 'sess_golden_1',
        prescriptionId: activeSlot.id,
        kindCode: 'BODYWEIGHT',
        sessionMode: MvSessionMode.guided,
        status: MvSessionStatus.completed,
        startedAt: startMs,
        endedAt: endMs,
        overallFeeling: 4,
        note: 'تمرین عالی و بدون درد انجام شد',
        createdAt: startMs,
        updatedAt: endMs,
      );

      expect(session.isFinished, isTrue);
      expect(session.elapsedMinutes, equals(30));
      expect(session.overallFeeling, equals(4));
      expect(session.note, equals('تمرین عالی و بدون درد انجام شد'));

      // Set logs
      final setLogs = [
        MvSetLog(
          id: 'set_1',
          sessionId: session.id,
          exerciseId: 'push_up',
          setNumber: 1,
          weight: 0,
          reps: 12,
          loggedAt: startMs + 60000,
        ),
        MvSetLog(
          id: 'set_2',
          sessionId: session.id,
          exerciseId: 'squat',
          setNumber: 1,
          weight: 0,
          reps: 15,
          loggedAt: startMs + 120000,
        ),
      ];

      // 4. Budget Progress Calculation (WHO standard)
      final kindsMap = {
        'BODYWEIGHT': const MovementKind(
          code: 'BODYWEIGHT',
          titleFa: 'تمرین با وزن بدن',
          emoji: '🏋️',
          family: MovementFamily.strength,
          baseMet: 5.0,
          metLow: 3.5,
          metHigh: 6.0,
          primaryMetric: MovementMetric.duration,
          secondaryMetric: MovementMetric.sets,
          isOutdoor: false,
          isSocial: false,
          needsVenue: false,
          jointImpact: 1,
          isCustom: false,
          isEnabled: true,
          usageCount: 1,
          sortOrder: 1,
        ),
      };

      final budgetDecision = budgetEngine.calculateWeeklyProgress(
        profile: profile,
        weekCompletedSessions: [session],
        currentDayOfWeekSat0: 3,
        kindsByCode: kindsMap,
      );

      expect(budgetDecision.value.moderateEquivalentMinutes, equals(30));
      expect(budgetDecision.value.rawMetMinutes, equals(150.0));
      expect(budgetDecision.value.strengthDays, equals(1));
      expect(budgetDecision.value.targetMin, equals(150));

      // 5. Muscle Distribution Calculation (InsightEngine)
      final exerciseMuscleMap = {
        'push_up': ['CHEST'],
        'squat': ['QUADS_GLUTES'],
      };

      final insightDecision = insightEngine.calculateMuscleDistribution(
        completedSetLogs: setLogs,
        exerciseMuscleMap: exerciseMuscleMap,
        completedSessionsCount: 3, // 3 sessions -> sufficient
      );

      expect(insightDecision.value, isNotNull);
      expect(insightDecision.value!.musclePercentages['CHEST'], equals(50.0));
      expect(insightDecision.value!.musclePercentages['QUADS_GLUTES'], equals(50.0));
      expect(insightDecision.hasEnoughData, isTrue);

      // 6. Streak Calculation (Consecutive Active Weeks)
      // 1 session in week is not active yet (threshold >= 2)
      final streak1 = MvHubController.calculateContinuousWeeks([session], referenceDate: currentSaturday);
      expect(streak1, equals(0));

      // Adding 2nd session in current week activates the week
      final session2 = MvSession(
        id: 'sess_golden_2',
        kindCode: 'BODYWEIGHT',
        status: MvSessionStatus.completed,
        startedAt: startMs + (48 * 3600 * 1000),
        endedAt: endMs + (48 * 3600 * 1000),
        createdAt: startMs,
        updatedAt: endMs,
      );

      final streak2 = MvHubController.calculateContinuousWeeks([session, session2], referenceDate: currentSaturday);
      expect(streak2, equals(1));
    });
  });
}
