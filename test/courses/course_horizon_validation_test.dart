import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/courses/logic/course_scheduler.dart';
import 'package:ritmo/features/courses/logic/course_validation.dart';
import 'package:ritmo/features/courses/models/course_models.dart';

void main() {
  group('Task 2 (N2) - Course Horizon Validation & ScheduleResult', () {
    test('CourseValidator throws TOTAL_EXCEEDS_HORIZON for 500 sessions with weeklyTarget=1', () {
      final course = Course(
        id: 'c_huge',
        title: 'دوره فوق‌العاده طولانی',
        totalSessions: 500,
        sessionDurationMinutes: 45,
        activityType: 'STUDY',
        status: CourseStatus.active,
        weeklyTargetSessions: 1,
        preferredDays: [6], // Saturday only
        courseType: CourseType.video,
        createdAt: 1000,
        updatedAt: 1000,
      );

      expect(
        () => CourseValidator.validateCourse(course),
        throwsA(
          isA<CourseValidationException>()
              .having((e) => e.code, 'code', 'TOTAL_EXCEEDS_HORIZON')
              .having((e) => e.messageFa, 'messageFa', contains('حداکثر ظرفیت'))
              .having((e) => e.messageFa, 'messageFa', contains('هدف هفتگی را حداقل به')),
        ),
      );
    });

    test('ScheduleResult returns valid dates and non-zero unscheduledCount when horizon exhausted', () {
      final start = DateTime(2026, 8, 1);
      // Try to schedule 500 sessions with weeklyTarget=1 (max 104 in 2-year horizon)
      final result = CourseScheduler.distributeSessions(
        pendingCount: 500,
        from: start,
        weeklyTarget: 1,
        preferredDays: [6],
      );

      expect(result.dates, isNotEmpty);
      expect(result.hasUnscheduled, isTrue);
      expect(result.isFullyScheduled, isFalse);
      expect(result.dates.length + result.unscheduledCount, equals(500));
      expect(result.unscheduledCount, greaterThan(0));
    });

    test('ScheduleResult isFullyScheduled when sessions fit within horizon', () {
      final start = DateTime(2026, 8, 1);
      final result = CourseScheduler.distributeSessions(
        pendingCount: 20,
        from: start,
        weeklyTarget: 3,
        preferredDays: [6, 1, 3],
      );

      expect(result.dates.length, equals(20));
      expect(result.unscheduledCount, equals(0));
      expect(result.hasUnscheduled, isFalse);
      expect(result.isFullyScheduled, isTrue);
    });
  });
}
