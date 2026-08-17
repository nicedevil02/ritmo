
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/features/courses/logic/course_date_contract.dart';
import 'package:ritmo/features/courses/logic/course_scheduler.dart';
import 'package:ritmo/features/courses/models/course_models.dart';

class CoursesEngineInput {
  CoursesEngineInput({
    required this.courses,
    required this.sessions,
    required this.currentEnergyLevel,
    required this.today,
  });

  final List<Course> courses;
  final List<CourseSession> sessions;
  final String currentEnergyLevel; // e.g. HIGH, MEDIUM, LOW
  final DateTime today;
}

class CoursesEngineOutput {
  CoursesEngineOutput({
    this.planningCourses = const [],
    this.allCourses = const [],
    required this.weeklyDoneSessions,
    this.weeklyTargetSessions = 0,
    required this.weeklyStudyMinutes,
    this.estimatedMinutesIncluded = false,
    this.studyStreakDays = 0,
    this.behindSchedule = const {},
    required this.todaySessions,
    required this.estimatedEnd,
    required this.completionRate,
    required this.scheduleAdherence,
    required this.estimationAccuracy,
    required this.requiredWeeklyPace,
    required this.masteryByCourse,
  });

  final List<Course> planningCourses;
  final List<Course> allCourses;
  final int weeklyDoneSessions;
  final int weeklyTargetSessions;
  final int weeklyStudyMinutes;
  final bool estimatedMinutesIncluded;
  final int studyStreakDays;
  final Map<String, int> behindSchedule; // courseId -> days behind
  final List<CourseSession> todaySessions; // pending sessions scheduled for today
  final Map<String, DateTime?> estimatedEnd;

  final Map<String, double> completionRate; // courseId -> 0..1
  final Map<String, double> scheduleAdherence; // done / scheduled up to today
  final Map<String, double> estimationAccuracy; // actual / estimated
  final Map<String, int> requiredWeeklyPace; // pace needed for targetEndDate
  final Map<String, double> masteryByCourse; // courseId -> 0..100
}

class CoursesEngine implements CachedEngine<CoursesEngineInput, CoursesEngineOutput> {
  @override
  Duration get ttl => const Duration(minutes: 5);

  @override
  String fingerprint(CoursesEngineInput input) {
    final dayStamp = CourseDate.toDayKey(input.today);
    var completedCount = 0;
    var skippedCount = 0;
    var maxUpdated = 0;
    for (final s in input.sessions) {
      if (s.isCompleted) completedCount++;
      if (s.isSkipped) skippedCount++;
      if (s.updatedAt > maxUpdated) maxUpdated = s.updatedAt;
    }
    return '$dayStamp|${input.courses.length}|${input.sessions.length}|$completedCount|$skippedCount|$maxUpdated|${input.currentEnergyLevel}';
  }

  @override
  void invalidate() {}

  @override
  Future<CoursesEngineOutput> calculate(CoursesEngineInput input) async {
    final coursesMap = <String, Course>{for (final c in input.courses) c.id: c};

    // 1. planningCourses = ONLY active & non-archived courses
    final planningCourses = input.courses.where((c) => c.status == CourseStatus.active && !c.isArchived).toList();

    // 2. achievementSessions = ALL sessions across ALL courses (active, paused, completed)
    final achievementSessions = input.sessions;

    final todayStr = CourseDate.toDayKey(input.today);

    // Calculate Farsi week boundaries for current week
    final satOfWeek = CourseDate.startOfFarsiWeek(input.today);
    final satStartMs = DateTime(satOfWeek.year, satOfWeek.month, satOfWeek.day).millisecondsSinceEpoch;
    final nextSat = CourseDate.addDays(satOfWeek, 7);
    final nextSatStartMs = DateTime(nextSat.year, nextSat.month, nextSat.day).millisecondsSinceEpoch;

    // A. Calculate weeklyDoneSessions & weeklyStudyMinutes from achievementSessions
    var weeklyDone = 0;
    var weeklyMinutes = 0;
    var includesEstimatedMinutes = false;

    for (final session in achievementSessions) {
      if (session.isCompleted) {
        int compTimeMs;
        if (session.completedAt != null && session.completedAt! > 0) {
          compTimeMs = session.completedAt!;
        } else {
          RitmoLog.warning('COURSES_ENGINE', 'Session ${session.id} completedAt is null, falling back to updatedAt');
          compTimeMs = session.updatedAt;
        }

        if (compTimeMs >= satStartMs && compTimeMs < nextSatStartMs) {
          weeklyDone++;
          if (session.actualDurationMinutes != null && session.actualDurationMinutes! > 0) {
            weeklyMinutes += session.actualDurationMinutes!;
          } else {
            final course = coursesMap[session.courseId];
            final estimated = course?.sessionDurationMinutes ?? 45;
            weeklyMinutes += estimated;
            includesEstimatedMinutes = true;
          }
        }
      }
    }

    // B. weeklyTargetSessions from planningCourses
    var totalWeeklyTarget = 0;
    for (final course in planningCourses) {
      totalWeeklyTarget += course.weeklyTargetSessions;
    }

    // C. studyStreakDays from achievementSessions
    final completedDates = <String>{};
    for (final session in achievementSessions) {
      if (session.isCompleted) {
        final compMs = (session.completedAt != null && session.completedAt! > 0) ? session.completedAt! : session.updatedAt;
        final compDate = DateTime.fromMillisecondsSinceEpoch(compMs);
        completedDates.add(CourseDate.toDayKey(compDate));
      }
    }

    var streak = 0;
    var checkDate = DateTime(input.today.year, input.today.month, input.today.day);
    final todayFormatted = CourseDate.toDayKey(checkDate);
    final yesterdayFormatted = CourseDate.toDayKey(CourseDate.addDays(checkDate, -1));

    final hasStreak = completedDates.contains(todayFormatted) || completedDates.contains(yesterdayFormatted);

    if (hasStreak) {
      if (!completedDates.contains(todayFormatted)) {
        checkDate = CourseDate.addDays(checkDate, -1);
      }

      while (completedDates.contains(CourseDate.toDayKey(checkDate))) {
        streak++;
        checkDate = CourseDate.addDays(checkDate, -1);
      }
    }

    final sessionsByCourse = <String, List<CourseSession>>{};
    for (final s in input.sessions) {
      (sessionsByCourse[s.courseId] ??= []).add(s);
    }

    // D. behindSchedule from planningCourses
    final behindMap = <String, int>{};
    for (final course in planningCourses) {
      final courseSessions = sessionsByCourse[course.id] ?? const [];
      final behindCount = CourseScheduler.daysBehind(sessions: courseSessions, today: input.today);
      behindMap[course.id] = behindCount;
    }

    // E. todaySessions from planningCourses
    final todaySess = <CourseSession>[];
    for (final course in planningCourses) {
      final courseSessions = sessionsByCourse[course.id] ?? const [];
      for (final session in courseSessions) {
        if (session.plannedDate == todayStr && !session.isCompleted && !session.isSkipped) {
          todaySess.add(session);
        }
      }
    }

    // F. estimatedEnd & requiredWeeklyPace from planningCourses
    final estEndMap = <String, DateTime?>{};
    final paceMap = <String, int>{};

    for (final course in planningCourses) {
      final courseSessions = sessionsByCourse[course.id] ?? const [];
      final pendingCount = courseSessions.where((s) => !s.isCompleted && !s.isSkipped).length;

      final est = CourseScheduler.estimatedEndDate(
        remaining: pendingCount,
        weeklyTarget: course.weeklyTargetSessions,
        from: input.today,
        preferredDays: course.preferredDays,
      );
      estEndMap[course.id] = est;

      if (course.targetEndDate != null && course.targetEndDate!.trim().isNotEmpty) {
        final targetDt = CourseDate.parseDayKey(course.targetEndDate);
        if (targetDt != null) {
          final daysLeft = CourseDate.daysBetween(input.today, targetDt);
          if (daysLeft > 0) {
            final weeksLeft = (daysLeft / 7.0).clamp(0.1, 100.0);
            final requiredPace = (pendingCount / weeksLeft).ceil();
            paceMap[course.id] = requiredPace.clamp(1, 21);
          }
        }
      }
    }

    // G. completionRate, scheduleAdherence, estimationAccuracy, masteryByCourse
    final rateMap = <String, double>{};
    final adherenceMap = <String, double>{};
    final accuracyMap = <String, double>{};
    final masteryMap = <String, double>{};

    for (final course in input.courses) {
      final courseSessions = sessionsByCourse[course.id] ?? const [];
      final learnSessions = courseSessions.where((s) => s.activityKind != CourseActivityKind.review).toList();
      final completedLearnCount = learnSessions.where((s) => s.isCompleted).length;
      final totalLearnCount = learnSessions.isNotEmpty ? learnSessions.length : course.totalSessions;

      rateMap[course.id] = (totalLearnCount > 0) ? (completedLearnCount / totalLearnCount).clamp(0.0, 1.0) : 0.0;

      // Adherence: done / (scheduled up to today)
      final scheduledUpToToday = courseSessions.where((s) => s.plannedDate != null && s.plannedDate!.compareTo(todayStr) <= 0).toList();
      if (scheduledUpToToday.isNotEmpty) {
        final doneScheduled = scheduledUpToToday.where((s) => s.isCompleted).length;
        adherenceMap[course.id] = (doneScheduled / scheduledUpToToday.length).clamp(0.0, 1.0);
      } else {
        adherenceMap[course.id] = 1.0;
      }

      // Accuracy: actual vs estimated
      final completedWithActual = courseSessions.where((s) => s.isCompleted && s.actualDurationMinutes != null && s.actualDurationMinutes! > 0).toList();
      if (completedWithActual.isNotEmpty) {
        var totalActual = 0;
        var totalEstimated = 0;
        for (final s in completedWithActual) {
          totalActual += s.actualDurationMinutes!;
          totalEstimated += s.estimatedDurationMinutes ?? course.sessionDurationMinutes;
        }
        if (totalEstimated > 0) {
          accuracyMap[course.id] = (totalActual / totalEstimated);
        }
      }

      // Mastery score: calculation
      if (course.masteryScore > 0) {
        masteryMap[course.id] = course.masteryScore;
      } else {
        final scoredSessions = learnSessions.where((s) => s.isCompleted && s.understandingScore != null).toList();
        if (scoredSessions.isNotEmpty) {
          final avgScore = scoredSessions.map((s) => s.understandingScore!).reduce((a, b) => a + b) / scoredSessions.length;
          masteryMap[course.id] = (avgScore / 5.0) * 100;
        } else {
          masteryMap[course.id] = (rateMap[course.id] ?? 0.0) * 100;
        }
      }
    }

    return CoursesEngineOutput(
      planningCourses: planningCourses,
      allCourses: input.courses,
      weeklyDoneSessions: weeklyDone,
      weeklyTargetSessions: totalWeeklyTarget,
      weeklyStudyMinutes: weeklyMinutes,
      estimatedMinutesIncluded: includesEstimatedMinutes,
      studyStreakDays: streak,
      behindSchedule: behindMap,
      todaySessions: todaySess,
      estimatedEnd: estEndMap,
      completionRate: rateMap,
      scheduleAdherence: adherenceMap,
      estimationAccuracy: accuracyMap,
      requiredWeeklyPace: paceMap,
      masteryByCourse: masteryMap,
    );
  }


  @override
  bool canRun(CoursesEngineInput input) => input.courses.isNotEmpty;

  @override
  List<Type> dependencies() => [];
}
