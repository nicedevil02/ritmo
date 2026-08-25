import 'package:ritmo/core/utils/shamsi_week.dart';
import 'package:ritmo/features/courses/logic/course_date_contract.dart';
import 'package:ritmo/features/courses/logic/course_validation.dart';
import 'package:ritmo/features/courses/models/course_models.dart';

class CourseScheduler {
  /// Sunday = 0, Monday = 1, Tuesday = 2, Wednesday = 3, Thursday = 4, Friday = 5, Saturday = 6
  static int getFarsiWeekday(DateTime dt) {
    return dt.weekday == 7 ? 0 : dt.weekday;
  }

  /// Saturday is the start of Farsi week
  @Deprecated('Use ShamsiWeek.saturdayOf instead')
  static DateTime getSaturdayOfWeek(DateTime dt) {
    return ShamsiWeek.saturdayOf(dt);
  }

  /// Calculates weekly occupancy map (SaturdayOfWeek -> count) for sessions already scheduled/completed.
  static Map<DateTime, int> weeklyOccupancy({
    required List<CourseSession> sessions,
  }) {
    final map = <DateTime, int>{};
    for (final s in sessions) {
      final dt = CourseDate.parseDayKey(s.plannedDate);
      if (dt != null) {
        final sat = CourseDate.startOfFarsiWeek(dt);
        final normalizedSat = DateTime(sat.year, sat.month, sat.day);
        map[normalizedSat] = (map[normalizedSat] ?? 0) + 1;
      }
    }
    return map;
  }

  /// Distributes pendingCount session dates starting from 'from'
  /// respecting weeklyTarget limit, preferredDays, occupiedWeeklyCounts, and blockedDates.
  /// (Fixes K-14, K-19, K-20, K-21, K-22, K-23, C6)
  static List<DateTime> distributeSessions({
    required int pendingCount,
    required DateTime from,
    required int weeklyTarget,
    required List<int> preferredDays,
    Map<DateTime, int> occupiedWeeklyCounts = const {},
    Set<DateTime> blockedDates = const {},
    bool throwOnIncomplete = false,
  }) {
    if (pendingCount <= 0) return const [];
    if (weeklyTarget < CourseLimits.minWeeklyTarget || weeklyTarget > CourseLimits.maxWeeklyTarget) {
      throw CourseValidationException(
        'INVALID_WEEKLY_TARGET',
        'هدف هفتگی باید بین ${CourseLimits.minWeeklyTarget} تا ${CourseLimits.maxWeeklyTarget} باشد.',
      );
    }

    final normalizedDays = CourseValidator.normalizePreferredDays(preferredDays);
    final blockedDayKeys = blockedDates.map(CourseDate.toDayKey).toSet();

    // Determine max sessions allowed per day based on weekly target vs available preferred days
    final maxPerDay = (weeklyTarget > normalizedDays.length)
        ? ((weeklyTarget + normalizedDays.length - 1) ~/ normalizedDays.length).clamp(1, CourseLimits.maxSessionsPerDay)
        : 1;

    final result = <DateTime>[];
    final weekCounts = <DateTime, int>{
      for (final entry in occupiedWeeklyCounts.entries)
        DateTime(entry.key.year, entry.key.month, entry.key.day): entry.value,
    };
    final dayCounts = <String, int>{};

    var currentDate = DateTime(from.year, from.month, from.day);
    var remaining = pendingCount;
    var safetyCounter = 0;
    const maxDaysLimit = CourseLimits.maxScheduleHorizonDays;

    while (remaining > 0 && safetyCounter < maxDaysLimit) {
      safetyCounter++;
      final farsiDay = getFarsiWeekday(currentDate);
      final currentDayKey = CourseDate.toDayKey(currentDate);
      final isBlocked = blockedDayKeys.contains(currentDayKey);
      final isPreferred = normalizedDays.contains(farsiDay);

      if (isPreferred && !isBlocked) {
        final satOfWeek = CourseDate.startOfFarsiWeek(currentDate);
        final normalizedSat = DateTime(satOfWeek.year, satOfWeek.month, satOfWeek.day);

        while (remaining > 0) {
          final currentWeekCount = weekCounts[normalizedSat] ?? 0;
          final currentDayCount = dayCounts[currentDayKey] ?? 0;

          if (currentWeekCount < weeklyTarget && currentDayCount < maxPerDay) {
            result.add(DateTime(currentDate.year, currentDate.month, currentDate.day));
            weekCounts[normalizedSat] = currentWeekCount + 1;
            dayCounts[currentDayKey] = currentDayCount + 1;
            remaining--;
          } else {
            break;
          }
        }
      }

      currentDate = CourseDate.addDays(currentDate, 1);
    }

    if (result.length != pendingCount && throwOnIncomplete) {
      throw CourseValidationException(
        'SCHEDULE_INCOMPLETE',
        'امکان زمان‌بندی کامل $pendingCount جلسه در بازه زمانی مجاز ($maxDaysLimit روز) وجود ندارد.',
      );
    }

    return result;
  }

  /// Calculates number of PENDING sessions whose plannedDate is before today.
  /// SKIPPED and COMPLETED sessions do NOT count as days behind. (Fixes K-17)
  static int daysBehind({
    required List<CourseSession> sessions,
    required DateTime today,
  }) {
    final todayStr = CourseDate.toDayKey(today);
    var count = 0;
    for (final session in sessions) {
      if (!session.isCompleted && !session.isSkipped && session.plannedDate != null) {
        if (session.plannedDate!.compareTo(todayStr) < 0) {
          count++;
        }
      }
    }
    return count;
  }

  /// Estimates the end date using distributeSessions (Fixes K-15)
  static DateTime? estimatedEndDate({
    required int remaining,
    required int weeklyTarget,
    required DateTime from,
    required List<int> preferredDays,
    Map<DateTime, int> occupiedWeeklyCounts = const {},
    Set<DateTime> blockedDates = const {},
  }) {
    if (remaining <= 0) return null;
    try {
      final dates = distributeSessions(
        pendingCount: remaining,
        from: from,
        weeklyTarget: weeklyTarget,
        preferredDays: preferredDays,
        occupiedWeeklyCounts: occupiedWeeklyCounts,
        blockedDates: blockedDates,
      );
      if (dates.isEmpty) return null;
      return dates.last;
    } catch (_) {
      return null;
    }
  }

  /// Reschedules all pending, non-user-scheduled sessions starting from [from] (Fixes K-18)
  static List<CourseSession> reschedulePendingSessions({
    required List<CourseSession> sessions,
    required DateTime from,
    required int weeklyTarget,
    required List<int> preferredDays,
    Set<DateTime> blockedDates = const {},
  }) {
    final pending = sessions.where((s) => !s.isCompleted && !s.isSkipped && !s.isUserScheduled).toList();
    if (pending.isEmpty) return sessions;

    final occupied = weeklyOccupancy(
      sessions: sessions.where((s) => s.isCompleted || s.isUserScheduled).toList(),
    );

    final newDates = distributeSessions(
      pendingCount: pending.length,
      from: from,
      weeklyTarget: weeklyTarget,
      preferredDays: preferredDays,
      occupiedWeeklyCounts: occupied,
      blockedDates: blockedDates,
    );

    final dateMap = <String, String>{};
    for (var i = 0; i < pending.length && i < newDates.length; i++) {
      dateMap[pending[i].id] = CourseDate.toDayKey(newDates[i]);
    }

    return sessions.map((s) {
      if (dateMap.containsKey(s.id)) {
        return s.copyWith(plannedDate: dateMap[s.id], plannedDateSet: true);
      }
      return s;
    }).toList();
  }
}
