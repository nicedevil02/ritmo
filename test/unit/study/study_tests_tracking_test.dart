import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/study/data/study_repository.dart';
import 'package:ritmo/features/study/domain/study_models.dart';

void main() {
  group('StudySession Test Performance Tracking Tests', () {
    test('Calculates accurate percentage and handles edge cases', () {
      const sessionWithTests = StudySession(
        id: 'sess_1',
        subjectId: 'sub_1',
        durationMinutes: 60,
        dateIso: '2026-08-25',
        testsTotal: 40,
        testsCorrect: 30,
        testsWrong: 6,
        testsEmpty: 4,
        createdAtMs: 0,
      );

      expect(sessionWithTests.hasTestResults, isTrue);
      expect(sessionWithTests.accuracyPercentage, 75.0); // 30/40 = 75%
      expect(sessionWithTests.konkurPercentage, 70.0);   // (30*3 - 6) / 120 = 84 / 120 = 70%

      const zeroSession = StudySession(
        id: 'sess_2',
        subjectId: 'sub_1',
        durationMinutes: 30,
        dateIso: '2026-08-25',
        testsTotal: 0,
        createdAtMs: 0,
      );

      expect(zeroSession.hasTestResults, isFalse);
      expect(zeroSession.accuracyPercentage, 0.0);
      expect(zeroSession.konkurPercentage, 0.0);
    });

    test('SubjectStats aggregates test metrics accurately', () {
      const stats = SubjectStats(
        subjectId: 'sub_math',
        totalMinutes: 180,
        sessionCount: 3,
        totalTests: 100,
        totalCorrect: 80,
        totalWrong: 15,
      );

      expect(stats.totalTests, 100);
      expect(stats.totalCorrect, 80);
      expect(stats.accuracyPercentage, 80.0);
    });
  });
}
