import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/courses/logic/course_date_contract.dart';
import 'package:ritmo/features/courses/logic/course_scheduler.dart';
import 'package:ritmo/features/courses/logic/course_validation.dart';
import 'package:ritmo/features/courses/models/course_models.dart';

void main() {
  group('CourseScheduler Unit Tests (C4 & Phase 2 K-14 to K-24)', () {
    test('distributeSessions: 7 sessions, weeklyTarget=3, preferredDays=[6,1,3] -> 7 dates, max 3 per week', () {
      final start = DateTime(2026, 8, 1); // Saturday
      final scheduleResult = CourseScheduler.distributeSessions(
        pendingCount: 7,
        from: start,
        weeklyTarget: 3,
        preferredDays: [6, 1, 3],
      );
      final dates = scheduleResult.dates;

      expect(dates.length, equals(7));
      expect(scheduleResult.unscheduledCount, equals(0));
      expect(scheduleResult.isFullyScheduled, isTrue);

      // Group by Saturday of week
      final weekCounts = <DateTime, int>{};
      for (final d in dates) {
        final sat = CourseScheduler.getSaturdayOfWeek(d);
        weekCounts[sat] = (weekCounts[sat] ?? 0) + 1;
      }

      for (final count in weekCounts.values) {
        expect(count, lessThanOrEqualTo(3));
      }
    });

    test('K-14: distributeSessions with pendingCount=0 returns empty list', () {
      final scheduleResult = CourseScheduler.distributeSessions(
        pendingCount: 0,
        from: DateTime(2026, 8, 1),
        weeklyTarget: 3,
        preferredDays: [6, 1, 3],
      );
      expect(scheduleResult.dates, isEmpty);
      expect(scheduleResult.unscheduledCount, equals(0));
    });

    test('K-14: distributeSessions with weeklyTarget=0 throws CourseValidationException', () {
      expect(
        () => CourseScheduler.distributeSessions(
          pendingCount: 5,
          from: DateTime.now(),
          weeklyTarget: 0,
          preferredDays: [6, 1, 3],
        ),
        throwsA(isA<CourseValidationException>()),
      );
    });

    test('K-20: distributeSessions with preferredDays=[9] normalizes to default without crash', () {
      final scheduleResult = CourseScheduler.distributeSessions(
        pendingCount: 3,
        from: DateTime(2026, 8, 1),
        weeklyTarget: 3,
        preferredDays: [9],
      );

      expect(scheduleResult.dates.length, equals(3));
      expect(scheduleResult.unscheduledCount, equals(0));
    });

    test('distributeSessions respects occupiedWeeklyCounts filling current week', () {
      final start = DateTime(2026, 8, 1); // Saturday
      final sat = CourseScheduler.getSaturdayOfWeek(start);

      final scheduleResult = CourseScheduler.distributeSessions(
        pendingCount: 3,
        from: start,
        weeklyTarget: 3,
        preferredDays: [6, 1, 3],
        occupiedWeeklyCounts: {sat: 3}, // current week is full!
      );
      final dates = scheduleResult.dates;

      expect(dates.length, equals(3));
      for (final d in dates) {
        expect(d.isAfter(start.add(const Duration(days: 6))), isTrue);
      }
    });

    test('K-19: distributeSessions respects blockedDates with DST / timezone safety', () {
      final start = DateTime(2026, 8, 1, 14, 30); // Saturday with time
      final blocked = DateTime(2026, 8, 1, 0, 0); // Midnight

      final scheduleResult = CourseScheduler.distributeSessions(
        pendingCount: 1,
        from: start,
        weeklyTarget: 3,
        preferredDays: [6, 1, 3],
        blockedDates: {blocked},
      );
      final dates = scheduleResult.dates;

      expect(dates.first, isNot(equals(DateTime(2026, 8, 1))));
      expect(CourseDate.toDayKey(dates.first), isNot(equals('2026-08-01')));
    });

    test('K-15: estimatedEndDate is 100% consistent with distributeSessions', () {
      final start = DateTime(2026, 8, 1);
      final scheduleResult = CourseScheduler.distributeSessions(
        pendingCount: 10,
        from: start,
        weeklyTarget: 3,
        preferredDays: [6, 1, 3],
      );
      final dates = scheduleResult.dates;

      final estimatedEnd = CourseScheduler.estimatedEndDate(
        remaining: 10,
        weeklyTarget: 3,
        from: start,
        preferredDays: [6, 1, 3],
      );

      expect(estimatedEnd, equals(dates.last));
      expect(CourseScheduler.estimatedEndDate(remaining: 0, weeklyTarget: 3, from: start, preferredDays: [6, 1, 3]), isNull);
    });

    test('K-16: weeklyOccupancy correctly groups sessions by Farsi Saturday', () {
      final s1 = CourseSession(
        id: 's1',
        courseId: 'c1',
        sessionNumber: 1,
        plannedDate: '2026-08-01', // Saturday
        completionStatus: SessionStatus.completed,
        createdAt: 1000,
        updatedAt: 1000,
      );
      final s2 = CourseSession(
        id: 's2',
        courseId: 'c1',
        sessionNumber: 2,
        plannedDate: '2026-08-03', // Monday (same week)
        completionStatus: SessionStatus.completed,
        createdAt: 1000,
        updatedAt: 1000,
      );
      final s3 = CourseSession(
        id: 's3',
        courseId: 'c1',
        sessionNumber: 3,
        plannedDate: '2026-08-08', // Next Saturday
        completionStatus: SessionStatus.pending,
        createdAt: 1000,
        updatedAt: 1000,
      );

      final occupancy = CourseScheduler.weeklyOccupancy(sessions: [s1, s2, s3]);
      final sat1 = DateTime(2026, 8, 1);
      final sat2 = DateTime(2026, 8, 8);

      expect(occupancy[sat1], equals(2));
      expect(occupancy[sat2], equals(1));
    });

    test('K-17: daysBehind counts only overdue pending sessions and ignores skipped/completed/future', () {
      final today = DateTime(2026, 8, 10);
      const pastStr = '2026-08-05';
      const futureStr = '2026-08-15';

      final pendingOverdue = CourseSession(
        id: 's1',
        courseId: 'c1',
        sessionNumber: 1,
        plannedDate: pastStr,
        completionStatus: SessionStatus.pending,
        createdAt: 1000,
        updatedAt: 1000,
      );
      final skippedPast = CourseSession(
        id: 's2',
        courseId: 'c1',
        sessionNumber: 2,
        plannedDate: pastStr,
        completionStatus: SessionStatus.skipped,
        createdAt: 1000,
        updatedAt: 1000,
      );
      final completedPast = CourseSession(
        id: 's3',
        courseId: 'c1',
        sessionNumber: 3,
        plannedDate: pastStr,
        completionStatus: SessionStatus.completed,
        createdAt: 1000,
        updatedAt: 1000,
      );
      final pendingFuture = CourseSession(
        id: 's4',
        courseId: 'c1',
        sessionNumber: 4,
        plannedDate: futureStr,
        completionStatus: SessionStatus.pending,
        createdAt: 1000,
        updatedAt: 1000,
      );

      final behind = CourseScheduler.daysBehind(
        sessions: [pendingOverdue, skippedPast, completedPast, pendingFuture],
        today: today,
      );

      expect(behind, equals(1));
    });

    test('K-18: reschedulePendingSessions updates only pending non-user-scheduled sessions', () {
      final from = DateTime(2026, 8, 1);
      final s1 = CourseSession(
        id: 's1',
        courseId: 'c1',
        sessionNumber: 1,
        plannedDate: '2026-07-20',
        completionStatus: SessionStatus.completed,
        createdAt: 1000,
        updatedAt: 1000,
      );
      final s2 = CourseSession(
        id: 's2',
        courseId: 'c1',
        sessionNumber: 2,
        plannedDate: '2026-08-25',
        isUserScheduled: true, // Manual sticky date
        completionStatus: SessionStatus.pending,
        createdAt: 1000,
        updatedAt: 1000,
      );
      final s3 = CourseSession(
        id: 's3',
        courseId: 'c1',
        sessionNumber: 3,
        plannedDate: '2026-07-25',
        completionStatus: SessionStatus.pending,
        createdAt: 1000,
        updatedAt: 1000,
      );

      final rescheduled = CourseScheduler.reschedulePendingSessions(
        sessions: [s1, s2, s3],
        from: from,
        weeklyTarget: 3,
        preferredDays: [6, 1, 3],
      );

      expect(rescheduled[0].plannedDate, equals('2026-07-20')); // preserved completed
      expect(rescheduled[1].plannedDate, equals('2026-08-25')); // preserved user scheduled
      expect(rescheduled[2].plannedDate, equals('2026-08-01')); // rescheduled to first available
    });

    test('K-21: Multiple sessions per day when weeklyTarget > preferredDays.length', () {
      final start = DateTime(2026, 8, 1); // Saturday
      // 1 preferred day (Saturday) with weeklyTarget = 2 -> 2 sessions on Saturday
      final scheduleResult = CourseScheduler.distributeSessions(
        pendingCount: 4,
        from: start,
        weeklyTarget: 2,
        preferredDays: [6],
      );
      final dates = scheduleResult.dates;

      expect(dates.length, equals(4));
      expect(scheduleResult.unscheduledCount, equals(0));
      // First two should be on 2026-08-01 (Saturday)
      expect(CourseDate.toDayKey(dates[0]), equals('2026-08-01'));
      expect(CourseDate.toDayKey(dates[1]), equals('2026-08-01'));
      // Next two should be on 2026-08-08 (Next Saturday)
      expect(CourseDate.toDayKey(dates[2]), equals('2026-08-08'));
      expect(CourseDate.toDayKey(dates[3]), equals('2026-08-08'));
    });
  });
}
