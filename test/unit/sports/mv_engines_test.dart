import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('7.1 ProfileEngine Tests', () {
    const engine = ProfileEngine();

    test('computeTrainingDays distributes days across week correctly', () {
      expect(engine.computeTrainingDays(1), equals([0])); // Sat
      expect(engine.computeTrainingDays(3), equals([0, 2, 4])); // Sat, Mon, Wed
      expect(engine.computeTrainingDays(5), equals([0, 1, 2, 3, 4]));
    });

    test('createQuickProfile produces fully functional profile with 3 inputs', () {
      final decision = engine.createQuickProfile(
        daysPerWeek: 3,
        sessionDuration: 'medium',
        trainingLocation: 'home',
      );

      expect(decision.value.onboardingCompleted, isTrue);
      expect(decision.value.daysPerWeek, equals(3));
      expect(decision.value.trainingDays, equals([0, 2, 4]));
      expect(decision.reasonFa, contains('روز در هفته'));
      expect(decision.hasEnoughData, isTrue);
    });
  });

  group('7.2 ReadinessEngine Tests', () {
    const engine = ReadinessEngine();

    test('Low sleep (<6h) reduces readiness score and triggers lighter recommendation', () {
      final decision = engine.evaluateReadiness(
        sleepMinutes: 300, // 5 hours
      );

      expect(decision.value, isIn([MvReadinessTier.light, MvReadinessTier.minimal]));
      expect(decision.reasonFa, contains('خواب کم'));
      expect(decision.sources, contains('sleep'));
    });

    test('Menstrual phase only applies when cycle consent is granted (AC-12)', () {
      final withoutConsent = engine.evaluateReadiness(
        isMenstrualPhase: true,
        cycleConsentGranted: false,
      );
      expect(withoutConsent.sources, isNot(contains('cycle')));

      final withConsent = engine.evaluateReadiness(
        isMenstrualPhase: true,
        cycleConsentGranted: true,
      );
      expect(withConsent.sources, contains('cycle'));
    });

    test('Absence of data returns honest message (Rule 7)', () {
      final decision = engine.evaluateReadiness();
      expect(decision.hasEnoughData, isFalse);
      expect(decision.reasonFa, contains('هنوز دادهٔ کافی'));
    });
  });

  group('7.3 PlanEngine Tests', () {
    const engine = PlanEngine();

    test('Generates 7 slots matching user training days and rest days', () {
      final now = DateTime(2026, 8, 22); // Saturday
      final profile = MvUserProfile(
        daysPerWeek: 3,
        trainingDays: const [0, 2, 4], // Sat, Mon, Wed
        createdAt: 100,
        updatedAt: 100,
      );

      final decision = engine.generateWeekPlan(
        profile: profile,
        weekSaturday: now,
      );

      expect(decision.value.length, equals(7));
      expect(decision.value[0].isRest, isFalse); // Sat
      expect(decision.value[1].isRest, isTrue);  // Sun
      expect(decision.value[2].isRest, isFalse); // Mon
      expect(decision.value[3].isRest, isTrue);  // Tue
      expect(decision.value[4].isRest, isFalse); // Wed
      expect(decision.value[5].isRest, isTrue);  // Thu
      expect(decision.value[6].isRest, isTrue);  // Fri
    });

    test('Deload week reduces target minutes and sets light intensity', () {
      final now = DateTime(2026, 8, 22);
      final profile = MvUserProfile(
        daysPerWeek: 3,
        deloadEveryNWeeks: 1, // trigger deload
        sessionDuration: 'medium', // 30 min
        createdAt: 100,
        updatedAt: 100,
      );

      final decision = engine.generateWeekPlan(
        profile: profile,
        weekSaturday: now,
      );

      final trainingSlot = decision.value.firstWhere((s) => !s.isRest);
      expect(trainingSlot.intensityTier, equals(MvIntensityTier.light));
      expect(trainingSlot.targetMinutes, lessThan(30));
      expect(trainingSlot.coachNoteFa, contains('سبک‌تر'));
    });
  });

  group('7.4 SelectionEngine & 7.5 SubstitutionEngine Tests', () {
    const selection = SelectionEngine();
    const substitution = SubstitutionEngine();

    final testPool = [
      const MvExercise(
        id: 'push_up',
        name: 'شنا سوئدی',
        category: 'CHEST',
        noisy: false,
        impact: 0,
        animationAsset: 'hw_push_up.json',
      ),
      const MvExercise(
        id: 'burpee',
        name: 'برپی',
        category: 'CARDIO',
        noisy: true,
        impact: 3,
        constraintNegative: 'knee',
      ),
      const MvExercise(
        id: 'squat',
        name: 'اسکات',
        category: 'QUADS_GLUTES',
        noisy: false,
        impact: 1,
      ),
    ];

    test('Apartment mode strictly excludes noisy & high-impact exercises (AC-09)', () {
      final decision = selection.selectExercises(
        pool: testPool,
        focusCodes: ['CARDIO', 'CHEST'],
        neighborFriendly: true,
      );

      final ids = decision.value.map((e) => e.id).toList();
      expect(ids, contains('push_up'));
      expect(ids, isNot(contains('burpee'))); // burpee is noisy
    });

    test('Physical limitations filter excludes conflicting exercises (AC-10)', () {
      final decision = selection.selectExercises(
        pool: testPool,
        focusCodes: ['CARDIO'],
        physicalLimitations: ['knee'],
      );

      final ids = decision.value.map((e) => e.id).toList();
      expect(ids, isNot(contains('burpee')));
    });

    test('SubstitutionEngine suggests valid non-noisy alternative on noise reason', () {
      final decision = substitution.suggestSubstitutes(
        currentExercise: testPool[1], // burpee
        reason: 'noise',
        similarCandidates: [testPool[0]], // push_up
        neighborFriendly: true,
      );

      expect(decision.value.length, equals(1));
      expect(decision.value.first.id, equals('push_up'));
      expect(decision.reasonFa, contains('بی‌صدا'));
    });
  });

  group('7.6 ProgressionEngine & 7.7 AdaptationEngine Tests', () {
    const progression = ProgressionEngine();
    const adaptation = AdaptationEngine();

    test('Progression increases reps after easy session feeling', () {
      const ex = MvExercise(id: 'push_up', name: 'شنا', category: 'CHEST', defaultReps: 10);
      const log = MvSetLog(id: '1', sessionId: 's', exerciseId: 'push_up', setNumber: 1, reps: 10, loggedAt: 100);

      final decision = progression.calculateNextTarget(
        exercise: ex,
        recentSetLogs: [log],
        lastFeeling: MvSessionFeeling.easy,
      );

      expect(decision.value.targetReps, equals(12));
      expect(decision.reasonFa, contains('۲ تکرار'));
    });

    test('AdaptationEngine proposes non-guilt compensation on upcoming rest day', () {
      const skippedSlot = MvSlot(
        id: 'slot_1',
        dateIso: '2026-08-25',
        headlineFa: 'قدرت بالاتنه',
        targetMinutes: 30,
        createdAt: 100,
        updatedAt: 100,
      );

      const restSlot = MvSlot(
        id: 'slot_2',
        dateIso: '2026-08-26',
        slotType: MvSlotType.rest,
        headlineFa: 'استراحت',
        createdAt: 100,
        updatedAt: 100,
      );

      final decision = adaptation.suggestCompensation(
        skippedSlot: skippedSlot,
        upcomingSlots: [restSlot],
      );

      expect(decision.value, isNotNull);
      expect(decision.value!.headlineFa, contains('جبران جلسه'));
    });
  });

  group('7.8 BudgetEngine, 7.9 InsightEngine, 7.10 Coach, 7.11 Reminder Tests', () {
    test('BudgetEngine calculates MET-min progress and forecasts after day 3', () {
      const budget = BudgetEngine();
      final profile = MvUserProfile(daysPerWeek: 3, createdAt: 100, updatedAt: 100);
      final sessions = [
        MvSession(id: '1', kindCode: 'running', startedAt: DateTime(2026, 8, 22).millisecondsSinceEpoch, endedAt: DateTime(2026, 8, 22).millisecondsSinceEpoch + 1800000, createdAt: 100, updatedAt: 100),
      ];

      final decision = budget.calculateWeeklyProgress(
        profile: profile,
        weekCompletedSessions: sessions,
        currentDayOfWeekSat0: 3, // Tuesday
      );

      expect(decision.value.currentActiveDays, equals(1));
      expect(decision.value.hasEnoughDataForForecast, isTrue);
    });

    test('InsightEngine detects neglected muscle group', () {
      const insight = InsightEngine();
      const slots = [
        MvSlot(id: '1', dateIso: '2026-08-22', focusCodes: ['CHEST', 'UPPER'], headlineFa: '', createdAt: 100, updatedAt: 100),
        MvSlot(id: '2', dateIso: '2026-08-24', focusCodes: ['CHEST', 'UPPER'], headlineFa: '', createdAt: 100, updatedAt: 100),
      ];

      final decision = insight.calculateMuscleDistribution(completedSlots: slots);
      expect(decision.value.neglectedMuscleGroupCode, equals('BACK'));
      expect(decision.value.suggestedActionFa, contains('عضلات پشت'));
    });

    test('CoachEngine generates contextual tips', () {
      const coach = CoachEngine();
      const profile = MvUserProfile(createdAt: 100, updatedAt: 100);
      const slot = MvSlot(id: '1', dateIso: '2026-08-25', headlineFa: 'جلسه', createdAt: 100, updatedAt: 100);

      final decision = coach.generateTip(profile: profile, slot: slot);
      expect(decision.value.textFa, isNotEmpty);
    });

    test('ReminderEngine schedules notification respecting active workout slot', () {
      const reminder = ReminderEngine();
      const slot = MvSlot(
        id: '1',
        dateIso: '2026-08-25',
        headlineFa: 'قدرت بالاتنه',
        plannedTime: '19:00',
        createdAt: 100,
        updatedAt: 100,
      );

      final decision = reminder.evaluateReminder(slot: slot);
      expect(decision.value.shouldSchedule, isTrue);
      expect(decision.value.time, equals('19:00'));
      expect(decision.value.messageFa, contains('قدرت بالاتنه'));
    });
  });
}
