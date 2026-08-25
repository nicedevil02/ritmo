import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/budget_engine.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';

void main() {
  group('WHO Physical Activity BudgetEngine Tests (S0-T4)', () {
    const budgetEngine = BudgetEngine();

    MovementKind makeKind({
      required String code,
      required double baseMet,
      MovementFamily family = MovementFamily.endurance,
    }) {
      return MovementKind(
        code: code,
        titleFa: code,
        emoji: '🏃',
        family: family,
        baseMet: baseMet,
        metLow: baseMet * 0.8,
        metHigh: baseMet * 1.2,
        primaryMetric: MovementMetric.duration,
        secondaryMetric: MovementMetric.none,
        isOutdoor: false,
        isSocial: false,
        needsVenue: false,
        jointImpact: 2,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );
    }

    final kindsMap = {
      'WALKING': makeKind(code: 'WALKING', baseMet: 3.5, family: MovementFamily.daily),
      'FOOTBALL': makeKind(code: 'FOOTBALL', baseMet: 7.0, family: MovementFamily.sport),
      'STRETCHING': makeKind(code: 'STRETCHING', baseMet: 2.3, family: MovementFamily.mindBody),
      'HIKING': makeKind(code: 'HIKING', baseMet: 6.0, family: MovementFamily.outdoor),
      'BODYWEIGHT': makeKind(code: 'BODYWEIGHT', baseMet: 5.0, family: MovementFamily.strength),
    };

    MvSession makeSession({
      required String id,
      required String kindCode,
      required int minutes,
      MvSessionStatus status = MvSessionStatus.completed,
      DateTime? date,
    }) {
      final dt = date ?? DateTime(2026, 8, 25, 10, 0); // Tuesday
      final start = dt.millisecondsSinceEpoch;
      final end = start + (minutes * 60 * 1000);
      return MvSession(
        id: id,
        kindCode: kindCode,
        status: status,
        startedAt: start,
        endedAt: end,
        createdAt: start,
        updatedAt: end,
      );
    }

    test('Table Item 1: WALKING (MET 3.5) 60 min -> moderateEquivalentMinutes == 60', () {
      final session = makeSession(id: 's1', kindCode: 'WALKING', minutes: 60);
      final decision = budgetEngine.calculateWeeklyProgress(
        weekCompletedSessions: [session],
        currentDayOfWeekSat0: 3,
        kindsByCode: kindsMap,
      );

      expect(decision.value.moderateEquivalentMinutes, equals(60));
    });

    test('Table Item 2: FOOTBALL (MET 7.0) 90 min -> moderateEquivalentMinutes == 180 (vigorous doubles)', () {
      final session = makeSession(id: 's2', kindCode: 'FOOTBALL', minutes: 90);
      final decision = budgetEngine.calculateWeeklyProgress(
        weekCompletedSessions: [session],
        currentDayOfWeekSat0: 3,
        kindsByCode: kindsMap,
      );

      expect(decision.value.moderateEquivalentMinutes, equals(180));
    });

    test('Table Item 3: STRETCHING (MET 2.3) 30 min -> moderateEquivalentMinutes == 0 (light does not count)', () {
      final session = makeSession(id: 's3', kindCode: 'STRETCHING', minutes: 30);
      final decision = budgetEngine.calculateWeeklyProgress(
        weekCompletedSessions: [session],
        currentDayOfWeekSat0: 3,
        kindsByCode: kindsMap,
      );

      expect(decision.value.moderateEquivalentMinutes, equals(0));
    });

    test('Table Item 4: HIKING (MET 6.0) 240 min -> moderateEquivalentMinutes == 480 (vigorous >= 6.0)', () {
      final session = makeSession(id: 's4', kindCode: 'HIKING', minutes: 240);
      final decision = budgetEngine.calculateWeeklyProgress(
        weekCompletedSessions: [session],
        currentDayOfWeekSat0: 3,
        kindsByCode: kindsMap,
      );

      expect(decision.value.moderateEquivalentMinutes, equals(480));
    });

    test('Table Item 5: Incomplete session (status != completed/partial) is NOT counted', () {
      final session = makeSession(
        id: 's5',
        kindCode: 'FOOTBALL',
        minutes: 90,
        status: MvSessionStatus.active,
      );
      final decision = budgetEngine.calculateWeeklyProgress(
        weekCompletedSessions: [session],
        currentDayOfWeekSat0: 3,
        kindsByCode: kindsMap,
      );

      expect(decision.value.moderateEquivalentMinutes, equals(0));
      expect(decision.value.rawMetMinutes, equals(0.0));
    });

    test('Budget Engine targets and forecast gating', () {
      // Forecast requires at least day 3 of week (sat0 >= 2)
      final session = makeSession(id: 's_sat', kindCode: 'WALKING', minutes: 60);

      // On Saturday (sat0 = 0) -> forecast is null
      final satDecision = budgetEngine.calculateWeeklyProgress(
        weekCompletedSessions: [session],
        currentDayOfWeekSat0: 0,
        kindsByCode: kindsMap,
      );
      expect(satDecision.value.hasEnoughDataForForecast, isFalse);
      expect(satDecision.value.forecastedModerateMinutes, isNull);
      expect(satDecision.value.targetMin, equals(150));
      expect(satDecision.value.targetOptimal, equals(300));
      expect(satDecision.value.strengthDaysTarget, equals(2));

      // On Monday (sat0 = 2) -> forecast is calculated
      final monDecision = budgetEngine.calculateWeeklyProgress(
        weekCompletedSessions: [session],
        currentDayOfWeekSat0: 2,
        kindsByCode: kindsMap,
      );
      expect(monDecision.value.hasEnoughDataForForecast, isTrue);
      expect(monDecision.value.forecastedModerateMinutes, isNotNull);
    });
  });
}
