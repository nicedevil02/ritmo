import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/insight_engine.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('InsightEngine Honest Muscle Distribution & Trends (S0-T5)', () {
    const insightEngine = InsightEngine();

    MvSetLog makeSetLog({
      required String id,
      required String exerciseId,
      required int setNumber,
    }) {
      return MvSetLog(
        id: id,
        sessionId: 'sess_1',
        exerciseId: exerciseId,
        setNumber: setNumber,
        weight: 0,
        reps: 10,
        loggedAt: 1000,
      );
    }

    test('Scenario 1: 0 sets -> returns null value and hasEnoughData == false', () {
      final decision = insightEngine.calculateMuscleDistribution(
        completedSetLogs: [],
        completedSessionsCount: 0,
      );

      expect(decision.value, isNull);
      expect(decision.hasEnoughData, isFalse);
    });

    test('Scenario 2: 6 sets chest + 4 sets legs -> CHEST 60%, LEGS 40% with hasEnoughData == true', () {
      final setLogs = [
        // 6 sets of chest
        for (int i = 1; i <= 6; i++)
          makeSetLog(id: 'c_$i', exerciseId: 'push_up', setNumber: i),
        // 4 sets of legs
        for (int i = 1; i <= 4; i++)
          makeSetLog(id: 'l_$i', exerciseId: 'squat', setNumber: i),
      ];

      final exerciseMuscleMap = {
        'push_up': ['CHEST'],
        'squat': ['LEGS'],
      };

      final decision = insightEngine.calculateMuscleDistribution(
        completedSetLogs: setLogs,
        exerciseMuscleMap: exerciseMuscleMap,
        completedSessionsCount: 3, // 3 sessions -> sufficient
      );

      expect(decision.value, isNotNull);
      final percentages = decision.value!.musclePercentages;
      expect(percentages['CHEST'], equals(60.0));
      expect(percentages['LEGS'], equals(40.0));
      expect(decision.hasEnoughData, isTrue);
    });

    test('Scenario 3: Fewer than 3 sessions -> hasEnoughData == false', () {
      final setLogs = [
        for (int i = 1; i <= 6; i++)
          makeSetLog(id: 'c_$i', exerciseId: 'push_up', setNumber: i),
      ];

      final exerciseMuscleMap = {
        'push_up': ['CHEST'],
      };

      final decision = insightEngine.calculateMuscleDistribution(
        completedSetLogs: setLogs,
        exerciseMuscleMap: exerciseMuscleMap,
        completedSessionsCount: 2, // < 3 sessions -> insufficient data
      );

      expect(decision.hasEnoughData, isFalse);
    });
  });
}
