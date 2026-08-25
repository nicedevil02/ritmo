import 'package:ritmo/features/courses/logic/course_date_contract.dart';
import 'package:ritmo/features/courses/logic/course_scheduler.dart';
import 'package:ritmo/features/courses/logic/course_validation.dart';
import 'package:ritmo/features/courses/logic/courses_repository.dart';
import 'package:ritmo/features/courses/models/course_models.dart';

class CatchupPlan {
  CatchupPlan({
    required this.courseId,
    required this.overdueSessionsCount,
    required this.proposedWeeklyTarget,
    required this.rescheduledSessions,
    required this.suggestedSkipsCount,
    required this.messageFa,
  });

  final String courseId;
  final int overdueSessionsCount;
  final int proposedWeeklyTarget;
  final List<CourseSession> rescheduledSessions;
  final int suggestedSkipsCount;
  final String messageFa;
}

class CourseCatchupEngine {
  static CatchupPlan generateCatchupPlan({
    required Course course,
    required List<CourseSession> sessions,
    required DateTime today,
    int maxAdditionalWeeklyTarget = 2,
    Set<DateTime> blockedDates = const {},
  }) {
    final overdueCount = CourseScheduler.daysBehind(sessions: sessions, today: today);

    if (overdueCount <= 0) {
      return CatchupPlan(
        courseId: course.id,
        overdueSessionsCount: 0,
        proposedWeeklyTarget: course.weeklyTargetSessions,
        rescheduledSessions: [],
        suggestedSkipsCount: 0,
        messageFa: 'شما کاملاً بر طبق برنامه‌ریزی پیش می‌روید! 👏',
      );
    }

    // Proposed new weekly target (clamp within limits)
    final proposedTarget = (course.weeklyTargetSessions + maxAdditionalWeeklyTarget).clamp(
      CourseLimits.minWeeklyTarget,
      CourseLimits.maxWeeklyTarget,
    );

    // For catch-up, all non-completed, non-skipped sessions are rescheduled
    final pendingToReschedule = sessions.where((s) => !s.isCompleted && !s.isSkipped).toList();
    final occupiedWeekly = CourseScheduler.weeklyOccupancy(
      sessions: sessions.where((s) => s.isCompleted).toList(),
    );

    List<DateTime> newDates;
    try {
      newDates = CourseScheduler.distributeSessions(
        pendingCount: pendingToReschedule.length,
        from: today,
        weeklyTarget: proposedTarget,
        preferredDays: course.preferredDays,
        occupiedWeeklyCounts: occupiedWeekly,
        blockedDates: blockedDates,
      );
    } on CourseValidationException catch (e) {
      return CatchupPlan(
        courseId: course.id,
        overdueSessionsCount: overdueCount,
        proposedWeeklyTarget: proposedTarget,
        rescheduledSessions: [],
        suggestedSkipsCount: overdueCount > CourseLimits.suggestedSkipOverdueThreshold
            ? overdueCount - CourseLimits.suggestedSkipOverdueThreshold
            : 0,
        messageFa: 'امکان زمان‌بندی مجدد خودکار وجود ندارد (${e.messageFa}). لطفاً هدف هفتگی یا روزهای انتخابی را تغییر دهید.',
      );
    } catch (_) {
      return CatchupPlan(
        courseId: course.id,
        overdueSessionsCount: overdueCount,
        proposedWeeklyTarget: proposedTarget,
        rescheduledSessions: [],
        suggestedSkipsCount: 0,
        messageFa: 'خطا در محاسبه برنامه جبرانی. لطفاً تنظیمات دوره را بررسی نمایید.',
      );
    }

    final rescheduled = <CourseSession>[];
    for (var i = 0; i < pendingToReschedule.length; i++) {
      final session = pendingToReschedule[i];
      String? dateStr;
      if (i < newDates.length) {
        dateStr = CourseDate.toDayKey(newDates[i]);
      }
      rescheduled.add(session.copyWith(
        plannedDate: dateStr,
        plannedDateSet: true,
        isUserScheduled: false,
      ));
    }

    int suggestedSkips = 0;
    if (overdueCount > CourseLimits.suggestedSkipOverdueThreshold) {
      suggestedSkips = overdueCount - CourseLimits.suggestedSkipOverdueThreshold;
    }

    // Compute realistic catch-up window
    final extraPerWeek = proposedTarget - course.weeklyTargetSessions;
    String msg;
    if (extraPerWeek <= 0) {
      msg = 'شما $overdueCount جلسه از برنامه عقب هستید. با هدف هفتگی فعلی امکان جبران وجود ندارد؛ پیشنهاد می‌شود هدف هفتگی را افزایش دهید.';
    } else {
      final weeksToCatchUp = (overdueCount / extraPerWeek).ceil();
      msg = overdueCount > 5
          ? 'شما $overdueCount جلسه از برنامه عقب هستید. پیشنهاد می‌کنیم هدف هفتگی را به $proposedTarget جلسه افزایش دهید تا ظرف حدود $weeksToCatchUp هفته جبران شود.'
          : 'شما $overdueCount جلسه عقب هستید. جلسات معوقه در روزهای آینده زمان‌بندی مجدد شدند.';
    }

    return CatchupPlan(
      courseId: course.id,
      overdueSessionsCount: overdueCount,
      proposedWeeklyTarget: proposedTarget,
      rescheduledSessions: rescheduled,
      suggestedSkipsCount: suggestedSkips,
      messageFa: msg,
    );
  }

  static Future<void> applyCatchupPlan(CatchupPlan plan) async {
    final course = await CoursesRepository.instance.getCourseById(plan.courseId);
    if (course == null) return;

    final updatedCourse = course.copyWith(
      weeklyTargetSessions: plan.proposedWeeklyTarget,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await CoursesRepository.instance.updateCourse(updatedCourse);
  }
}
