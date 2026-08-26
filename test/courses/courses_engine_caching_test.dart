import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/analytics/courses_engine.dart';
import 'package:ritmo/features/courses/models/course_models.dart';

void main() {
  group('Task 7 (M13) - CoursesEngine Caching & Invalidation', () {
    final now = DateTime.now();

    final testCourse = Course(
      id: 'c_eng_1',
      title: 'Caching Test Course',
      totalSessions: 10,
      sessionDurationMinutes: 45,
      weeklyTargetSessions: 3,
      preferredDays: [6, 1, 3],
      courseType: CourseType.video,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    );

    final testSessions = [
      CourseSession(
        id: 'sess_1',
        courseId: 'c_eng_1',
        sessionNumber: 1,
        displayOrder: 1,
        plannedDate: '2026-08-26',
        completionStatus: SessionStatus.completed,
        completedAt: now.millisecondsSinceEpoch,
        actualDurationMinutes: 50,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      ),
      CourseSession(
        id: 'sess_2',
        courseId: 'c_eng_1',
        sessionNumber: 2,
        displayOrder: 2,
        plannedDate: '2026-08-28',
        completionStatus: SessionStatus.pending,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      ),
    ];

    test('fingerprint accurately reflects changes in sessions, courses, and energy level', () {
      final engine = CoursesEngine();

      final input1 = CoursesEngineInput(
        courses: [testCourse],
        sessions: testSessions,
        currentEnergyLevel: 'MEDIUM',
        today: now,
      );

      final fp1 = engine.fingerprint(input1);
      expect(fp1, isNotEmpty);

      // Same input produces identical fingerprint
      final input1Same = CoursesEngineInput(
        courses: [testCourse],
        sessions: testSessions,
        currentEnergyLevel: 'MEDIUM',
        today: now,
      );
      expect(engine.fingerprint(input1Same), equals(fp1));

      // Different energy level changes fingerprint
      final input2 = CoursesEngineInput(
        courses: [testCourse],
        sessions: testSessions,
        currentEnergyLevel: 'HIGH',
        today: now,
      );
      expect(engine.fingerprint(input2), isNot(equals(fp1)));

      // Modifying a session updates fingerprint
      final modifiedSessions = [
        testSessions[0].copyWith(updatedAt: now.millisecondsSinceEpoch + 10000),
        testSessions[1],
      ];
      final input3 = CoursesEngineInput(
        courses: [testCourse],
        sessions: modifiedSessions,
        currentEnergyLevel: 'MEDIUM',
        today: now,
      );
      expect(engine.fingerprint(input3), isNot(equals(fp1)));
    });

    test('calculate returns cached instance when fingerprint is identical within TTL', () async {
      final engine = CoursesEngine(instanceTtl: const Duration(minutes: 5));

      final input = CoursesEngineInput(
        courses: [testCourse],
        sessions: testSessions,
        currentEnergyLevel: 'MEDIUM',
        today: now,
      );

      final result1 = await engine.calculate(input);
      final result2 = await engine.calculate(input);

      // Should return exact same cached reference
      expect(identical(result1, result2), isTrue);
      expect(result1.weeklyDoneSessions, equals(1));
    });

    test('invalidate clears cached output and re-computes on next calculate', () async {
      final engine = CoursesEngine(instanceTtl: const Duration(minutes: 5));

      final input = CoursesEngineInput(
        courses: [testCourse],
        sessions: testSessions,
        currentEnergyLevel: 'MEDIUM',
        today: now,
      );

      final result1 = await engine.calculate(input);
      engine.invalidate();
      final result2 = await engine.calculate(input);

      // Different instances after cache invalidation, but identical values
      expect(identical(result1, result2), isFalse);
      expect(result2.weeklyDoneSessions, equals(result1.weeklyDoneSessions));
    });
  });
}
