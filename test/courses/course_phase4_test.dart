import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/courses/logic/course_adaptive_engine.dart';
import 'package:ritmo/features/courses/logic/course_catchup_engine.dart';
import 'package:ritmo/features/courses/logic/sm2_review_engine.dart';
import 'package:ritmo/features/courses/models/course_models.dart';

void main() {
  group('Phase 4 Tests (K-38 to K-51)', () {
    test('K-39 & K-41: Course model complete serialization and copyWith nullable resets', () {
      final course = Course(
        id: 'c_test_p4',
        title: 'Python Mastery',
        totalSessions: 20,
        sessionDurationMinutes: 45,
        activityType: 'STUDY',
        zoneId: 'z_tech',
        isArchived: false,
        energyRule: CourseEnergyRule.all,
        createdAt: 1000,
        updatedAt: 2000,
        courseType: CourseType.skill,
        unitLabel: 'تمرین',
        emoji: '🐍',
        colorHex: '#306998',
        provider: 'Udemy',
        weeklyTargetSessions: 4,
        isAdaptive: true,
        preferredDays: [6, 1, 3, 4],
        preferredTime: '18:30',
        reminderEnabled: true,
        linkedGoalId: 'g_python',
        status: CourseStatus.active,
        completedAt: null,
        targetEndDate: '2026-12-31',
        adaptiveLastAppliedAt: 1500,
        masteryScore: 85.5,
        reviewEnabled: true,
      );

      final map = course.toMap();
      final reconstructed = Course.fromMap(map);

      expect(reconstructed.id, equals(course.id));
      expect(reconstructed.title, equals(course.title));
      expect(reconstructed.totalSessions, equals(20));
      expect(reconstructed.sessionDurationMinutes, equals(45));
      expect(reconstructed.courseType, equals(CourseType.skill));
      expect(reconstructed.preferredDays, equals([6, 1, 3, 4]));
      expect(reconstructed.isAdaptive, isTrue);
      expect(reconstructed.reminderEnabled, isTrue);
      expect(reconstructed.reviewEnabled, isTrue);
      expect(reconstructed.masteryScore, equals(85.5));

      // Test copyWith resetting nullable fields
      final modified = course.copyWith(
        linkedGoalIdSet: true,
        linkedGoalId: null,
        targetEndDateSet: true,
        targetEndDate: null,
      );
      expect(modified.linkedGoalId, isNull);
      expect(modified.targetEndDate, isNull);
    });

    test('K-48: SM-2 Review Engine interval progression and EF updates', () {
      final from = DateTime(2026, 8, 1);

      // Repetition 1 with perfect score (5)
      final r1 = SM2ReviewEngine.calculateNextReview(
        qualityScore: 5,
        previousRepetitions: 0,
        previousIntervalDays: 1,
        previousEasinessFactor: 2.5,
        fromDate: from,
      );
      expect(r1.repetitions, equals(1));
      expect(r1.intervalDays, equals(1));
      expect(r1.easinessFactor, greaterThanOrEqualTo(2.5));

      // Repetition 2
      final r2 = SM2ReviewEngine.calculateNextReview(
        qualityScore: 5,
        previousRepetitions: 1,
        previousIntervalDays: 1,
        previousEasinessFactor: r1.easinessFactor,
        fromDate: r1.nextReviewDate,
      );
      expect(r2.repetitions, equals(2));
      expect(r2.intervalDays, equals(6));

      // Repetition 3
      final r3 = SM2ReviewEngine.calculateNextReview(
        qualityScore: 4,
        previousRepetitions: 2,
        previousIntervalDays: 6,
        previousEasinessFactor: r2.easinessFactor,
        fromDate: r2.nextReviewDate,
      );
      expect(r3.repetitions, equals(3));
      expect(r3.intervalDays, greaterThanOrEqualTo(12));

      // Blackout score (1) resets repetitions to 0 and interval to 1
      final rFail = SM2ReviewEngine.calculateNextReview(
        qualityScore: 1,
        previousRepetitions: 3,
        previousIntervalDays: 15,
        previousEasinessFactor: 2.5,
        fromDate: from,
      );
      expect(rFail.repetitions, equals(0));
      expect(rFail.intervalDays, equals(1));
      expect(rFail.easinessFactor, greaterThanOrEqualTo(1.3)); // EF floor
    });

    test('K-49: CourseCatchupEngine generates realistic catchup plan when behind', () {
      final today = DateTime(2026, 8, 10);
      final course = Course(
        id: 'c_catchup',
        title: 'Catchup Test',
        totalSessions: 10,
        sessionDurationMinutes: 30,
        weeklyTargetSessions: 3,
        createdAt: 0,
        updatedAt: 0,
        courseType: CourseType.video,
        preferredDays: [6, 1, 3],
      );

      final overdueSession = CourseSession(
        id: 's_od',
        courseId: 'c_catchup',
        sessionNumber: 1,
        plannedDate: '2026-08-01', // overdue
        completionStatus: SessionStatus.pending,
        createdAt: 0,
        updatedAt: 0,
      );
      final pendingSession = CourseSession(
        id: 's_fut',
        courseId: 'c_catchup',
        sessionNumber: 2,
        plannedDate: '2026-08-15',
        completionStatus: SessionStatus.pending,
        createdAt: 0,
        updatedAt: 0,
      );

      final plan = CourseCatchupEngine.generateCatchupPlan(
        course: course,
        sessions: [overdueSession, pendingSession],
        today: today,
      );

      expect(plan.overdueSessionsCount, equals(1));
      expect(plan.proposedWeeklyTarget, greaterThanOrEqualTo(course.weeklyTargetSessions));
      expect(plan.rescheduledSessions.length, equals(2));
    });

    test('K-50: CourseAdaptiveEngine returns null if course is not adaptive or throttled', () async {
      final today = DateTime(2026, 8, 10);
      final nonAdaptiveCourse = Course(
        id: 'c_non_ad',
        title: 'Non-Adaptive',
        totalSessions: 10,
        sessionDurationMinutes: 30,
        weeklyTargetSessions: 3,
        isAdaptive: false,
        createdAt: 0,
        updatedAt: 0,
        courseType: CourseType.video,
        preferredDays: [6, 1, 3],
      );

      final res = await CourseAdaptiveEngine.evaluateAndAdjustCourse(
        course: nonAdaptiveCourse,
        sessions: const [],
        today: today,
      );

      expect(res, isNull);
    });
  });
}
