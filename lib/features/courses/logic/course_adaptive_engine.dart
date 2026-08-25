import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/features/courses/logic/course_date_contract.dart';
import 'package:ritmo/features/courses/logic/course_scheduler.dart';
import 'package:ritmo/features/courses/logic/courses_repository.dart';
import 'package:ritmo/features/courses/models/course_models.dart';

class AdaptiveAdjustmentResult {
  AdaptiveAdjustmentResult({
    required this.courseId,
    required this.oldWeeklyTarget,
    required this.newWeeklyTarget,
    required this.reasonFa,
    required this.appliedAt,
  });

  final String courseId;
  final int oldWeeklyTarget;
  final int newWeeklyTarget;
  final String reasonFa;
  final DateTime appliedAt;
}

class CourseAdaptiveEngine {
  /// Evaluates whether an adaptive course needs target adjustment without modifying DB
  static AdaptiveAdjustmentResult? proposeAdjustment({
    required Course course,
    required List<CourseSession> sessions,
    required DateTime today,
  }) {
    if (!course.isAdaptive) return null;

    final nowMs = today.millisecondsSinceEpoch;

    // 1. Guard: Check if applied in last 14 days
    if (course.adaptiveLastAppliedAt != null) {
      final daysSinceLast = (nowMs - course.adaptiveLastAppliedAt!) / (1000 * 60 * 60 * 24);
      if (daysSinceLast < 14) {
        return null;
      }
    }

    final overdueCount = CourseScheduler.daysBehind(sessions: sessions, today: today);

    int proposedTarget = course.weeklyTargetSessions;
    String? reason;

    if (overdueCount >= 6 && course.weeklyTargetSessions > CourseLimits.minWeeklyTarget) {
      proposedTarget = (course.weeklyTargetSessions - 1).clamp(CourseLimits.minWeeklyTarget, CourseLimits.maxWeeklyTarget);
      reason = 'به دلیل انباشت $overdueCount جلسه معوقه، ریتم هفتگی برای جلوگیری از فشار مطالعه به $proposedTarget جلسه کاهش یافت.';
    } else {
      // Check last 2 weeks completion rate (DST-safe)
      final satCurrent = CourseDate.startOfFarsiWeek(today);
      final satPrev1 = CourseDate.addDays(satCurrent, -7);
      final satPrev2 = CourseDate.addDays(satCurrent, -14);

      final satCurrentMs = satCurrent.millisecondsSinceEpoch;
      final sat1Ms = satPrev1.millisecondsSinceEpoch;
      final sat2Ms = satPrev2.millisecondsSinceEpoch;

      final prevWeek1Done = sessions.where((s) => s.isCompleted && s.completedAt != null && s.completedAt! >= sat1Ms && s.completedAt! < satCurrentMs).length;
      final prevWeek2Done = sessions.where((s) => s.isCompleted && s.completedAt != null && s.completedAt! >= sat2Ms && s.completedAt! < sat1Ms).length;

      if (prevWeek1Done >= course.weeklyTargetSessions * 1.5 && prevWeek2Done >= course.weeklyTargetSessions * 1.5) {
        proposedTarget = (course.weeklyTargetSessions + 1).clamp(CourseLimits.minWeeklyTarget, CourseLimits.maxWeeklyTarget);
        reason = 'به دلیل سرعت بالای مطالعه شما در دو هفته گذشته، ریتم هفتگی به $proposedTarget جلسه افزایش یافت! 🚀';
      } else if (prevWeek1Done < course.weeklyTargetSessions * 0.5 && prevWeek2Done < course.weeklyTargetSessions * 0.5 && course.weeklyTargetSessions > CourseLimits.minWeeklyTarget) {
        proposedTarget = (course.weeklyTargetSessions - 1).clamp(CourseLimits.minWeeklyTarget, CourseLimits.maxWeeklyTarget);
        reason = 'به دلیل مشغله زیاد در دو هفته اخیر، هدف هفتگی به $proposedTarget جلسه تنظیم شد تا ریتم یادگیری حفظ شود.';
      }
    }

    if (proposedTarget == course.weeklyTargetSessions || reason == null) {
      return null;
    }

    return AdaptiveAdjustmentResult(
      courseId: course.id,
      oldWeeklyTarget: course.weeklyTargetSessions,
      newWeeklyTarget: proposedTarget,
      reasonFa: reason,
      appliedAt: today,
    );
  }

  /// Applies a proposed adaptive adjustment to the course in DB
  static Future<void> applyAdjustment(Course course, AdaptiveAdjustmentResult proposal) async {
    final nowMs = proposal.appliedAt.millisecondsSinceEpoch;
    final updatedCourse = course.copyWith(
      weeklyTargetSessions: proposal.newWeeklyTarget,
      adaptiveLastAppliedAt: nowMs,
      adaptiveLastAppliedAtSet: true,
      updatedAt: nowMs,
    );

    await CoursesRepository.instance.updateCourse(updatedCourse);
    RitmoLog.info('COURSES', 'Applied adaptive course adjustment for ${course.id}: ${proposal.oldWeeklyTarget} -> ${proposal.newWeeklyTarget} (${proposal.reasonFa})');
    RitmoEventBus().fire(RitmoEvent(
      type: 'CoursesChanged',
      payload: {
        'courseId': course.id,
        'reason': 'ADAPTIVE_ADJUSTMENT',
        'oldWeeklyTarget': proposal.oldWeeklyTarget,
        'newWeeklyTarget': proposal.newWeeklyTarget,
        'explanation': proposal.reasonFa,
      },
    ));
  }

  /// Evaluates and optionally adjusts the course directly (backward compatible)
  static Future<AdaptiveAdjustmentResult?> evaluateAndAdjustCourse({
    required Course course,
    required List<CourseSession> sessions,
    required DateTime today,
    bool autoApply = true,
  }) async {
    final proposal = proposeAdjustment(
      course: course,
      sessions: sessions,
      today: today,
    );

    if (proposal == null) return null;

    if (autoApply) {
      await applyAdjustment(course, proposal);
    }

    return proposal;
  }
}
