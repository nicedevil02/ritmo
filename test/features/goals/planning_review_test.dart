import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/goals/logic/planning_review_calculator.dart';
import 'package:ritmo/features/goals/logic/planning_review_repository.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlanningReviewCalculator & Stats (V-06 Tests)', () {
    const calc = PlanningReviewCalculator();

    test('1. Calibration score is null when plannedMinutes < 120, and computed when >= 120', () {
      // Under 120 minutes
      final underStats = calc.compute(
        plannedMinutes: 90,
        completedMinutes: 90,
        movedMinutes: 0,
        droppedMinutes: 0,
      );
      expect(underStats.calibrationScore, isNull);

      // 120 minutes or more
      final validStats = calc.compute(
        plannedMinutes: 200,
        completedMinutes: 160,
        movedMinutes: 20,
        droppedMinutes: 20,
      );
      expect(validStats.calibrationScore, isNotNull);
      expect(validStats.calibrationScore, closeTo(0.8, 0.01));
    });

    test('2. Calibration score is clamped to 1.0 maximum', () {
      final overStats = calc.compute(
        plannedMinutes: 150,
        completedMinutes: 200,
        movedMinutes: 0,
        droppedMinutes: 0,
      );
      expect(overStats.calibrationScore, equals(1.0));
    });

    test('3. Stats correctly preserve movedMinutes and droppedMinutes counts', () {
      final stats = calc.compute(
        plannedMinutes: 300,
        completedMinutes: 150,
        movedMinutes: 90,
        droppedMinutes: 60,
      );
      expect(stats.movedMinutes, equals(90));
      expect(stats.droppedMinutes, equals(60));
      expect(stats.plannedMinutes, equals(300));
      expect(stats.completedMinutes, equals(150));
    });

    test('4. PlanningReviewItem mapping and serialization roundtrip', () {
      final item = PlanningReviewItem(
        id: 'rev_1',
        cycleId: 'cycle_week_1',
        reviewType: 'END_CYCLE',
        plannedMinutes: 300,
        completedMinutes: 240,
        movedMinutes: 30,
        droppedMinutes: 30,
        unplannedCompletedMinutes: 0,
        calibrationScore: 0.8,
        answersJson: '{"q1":"خوب بود"}',
        createdAt: 1700000000000,
      );

      final map = item.toMap();
      expect(map['id'], equals('rev_1'));
      expect(map['reviewType'], equals('END_CYCLE'));
      expect(map['calibrationScore'], equals(0.8));

      final restored = PlanningReviewItem.fromMap(map);
      expect(restored.id, equals(item.id));
      expect(restored.cycleId, equals(item.cycleId));
      expect(restored.calibrationScore, equals(0.8));
    });
  });
}
