import 'package:ritmo/core/domain/engines/zone_engine.dart';
import 'package:ritmo/core/domain/realm/realm_mode.dart';
import 'package:ritmo/core/domain/realm/realm_state.dart';
import 'package:ritmo/core/domain/realm/schedule_bounds.dart';

export 'package:ritmo/core/domain/realm/realm_mode.dart';
export 'package:ritmo/core/domain/realm/realm_state.dart';
export 'package:ritmo/core/domain/realm/schedule_bounds.dart';

abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime now() => DateTime.now();
}

class ActiveRealmResolver {
  const ActiveRealmResolver({this.clock = const SystemClock()});

  final Clock clock;

  /// Resolves the currently active realm state given loaded realms, schedules, and manual override.
  ActiveRealmState resolve({
    required List<RealmData> realms,
    required List<RealmScheduleData> schedules,
    String? overrideRealmId,
    int? overrideUntilMs,
    int? overrideStartedMs,
  }) {
    final now = clock.now();
    final nowMs = now.millisecondsSinceEpoch;

    // 1. Check manual override state (ق-۷, B-07)
    if (overrideRealmId != null &&
        overrideRealmId.isNotEmpty &&
        overrideUntilMs != null &&
        nowMs < overrideUntilMs) {
      final overrideRealm = realms.firstWhere(
        (r) => r.id == overrideRealmId,
        orElse: () => RealmData(
          id: overrideRealmId,
          name: 'قلمرو دستی',
          colorHex: '#6366F1',
          icon: '🎯',
          mode: RealmMode.normal,
        ),
      );

      final expireAt = DateTime.fromMillisecondsSinceEpoch(overrideUntilMs);
      final remaining = expireAt.difference(now);

      // B-07: Calculate elapsed progress accurately if started time is available
      final double progress;
      final DateTime? startedAt;
      if (overrideStartedMs != null && overrideStartedMs > 0 && overrideStartedMs < overrideUntilMs) {
        startedAt = DateTime.fromMillisecondsSinceEpoch(overrideStartedMs);
        final total = overrideUntilMs - overrideStartedMs;
        final elapsed = nowMs - overrideStartedMs;
        progress = total <= 0 ? 1.0 : (elapsed / total).clamp(0.0, 1.0);
      } else {
        startedAt = null;
        progress = 1.0;
      }

      // Find next scheduled realm to build honest explanation
      final nextSchedule = _findNextSchedule(now, realms, schedules);

      final explanation =
          'چون خودت تا ساعت ${_formatTime(expireAt)} این قلمرو را به صورت دستی فعال کردی.';

      return ManualRealmState(
        realm: overrideRealm,
        expireAt: expireAt,
        startedAt: startedAt,
        remaining: remaining.isNegative ? Duration.zero : remaining,
        progress: progress,
        explanation: explanation,
        nextRealmName: nextSchedule?.realm.name,
        nextRealmTimeStr: nextSchedule != null
            ? _formatTime(nextSchedule.scheduleStartDt)
            : null,
      );
    }

    // 2. Check scheduled realms
    final activeMatchingSchedules =
        <({
          RealmData realm,
          RealmScheduleData schedule,
          int durationMin,
          DateTime startDt,
          DateTime endDt,
        })>[];

    final currentWeekday = now.weekday;

    for (final schedule in schedules) {
      if (!schedule.daysOfWeek.contains(currentWeekday)) {
        continue;
      }

      final isWithin = ZoneEngine.isTimeWithinRange(
        time: now,
        startTimeStr: schedule.startTime,
        endTimeStr: schedule.endTime,
      );

      if (isWithin) {
        final realm = realms.firstWhere(
          (r) => r.id == schedule.zoneId,
          orElse: () => RealmData(
            id: schedule.zoneId,
            name: 'قلمرو زمان‌بندی‌شده',
            colorHex: '#6366F1',
            icon: '🎯',
            mode: RealmMode.normal,
          ),
        );

        final times = calculateScheduleBounds(
          now: now,
          startTime: schedule.startTime,
          endTime: schedule.endTime,
        );
        final durMin = times.endDt.difference(times.startDt).inMinutes;

        activeMatchingSchedules.add((
          realm: realm,
          schedule: schedule,
          durationMin: durMin > 0 ? durMin : 1,
          startDt: times.startDt,
          endDt: times.endDt,
        ));
      }
    }

    if (activeMatchingSchedules.isNotEmpty) {
      // Priority Rule (ق-۹):
      // 1. Shorter duration schedule wins (more specific window)
      // 2. Tie-breaker: Newer created date
      activeMatchingSchedules.sort((a, b) {
        final durComp = a.durationMin.compareTo(b.durationMin);
        if (durComp != 0) return durComp;
        final aCreated = a.realm.createdAt ?? 0;
        final bCreated = b.realm.createdAt ?? 0;
        return bCreated.compareTo(aCreated);
      });

      final winner = activeMatchingSchedules.first;
      final totalDuration = winner.endDt.difference(winner.startDt);
      final elapsed = now.difference(winner.startDt);
      final remaining = winner.endDt.difference(now);

      final progress = totalDuration.inSeconds > 0
          ? (elapsed.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0)
          : 1.0;

      final explanation =
          'چون امروز ${_weekdayFa(now.weekday)} است و ساعت ${_formatTime(now)} در بازه ${_formatTime(winner.startDt)} الی ${_formatTime(winner.endDt)} قلمرو «${winner.realm.name}» قرار دارد.';

      return ScheduledRealmState(
        realm: winner.realm,
        schedule: winner.schedule,
        startsAt: winner.startDt,
        endsAt: winner.endDt,
        remaining: remaining.isNegative ? Duration.zero : remaining,
        progress: progress,
        explanation: explanation,
      );
    }

    // 3. Check default realm fallback (B-12)
    final defaultRealmCandidates = realms.where((r) => r.isDefault).toList();
    if (defaultRealmCandidates.isNotEmpty) {
      final defaultRealm = defaultRealmCandidates.first;
      final nextSchedule = _findNextSchedule(now, realms, schedules);

      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final remaining = nextSchedule != null
          ? nextSchedule.scheduleStartDt.difference(now)
          : endOfToday.difference(now);

      final explanation = nextSchedule != null
          ? 'چون خارج از زمان‌بندی هستی، قلمرو پیش‌فرض «${defaultRealm.name}» تا شروع قلمرو بعدی (${_formatTime(nextSchedule.scheduleStartDt)}) فعال است.'
          : 'چون هیچ زمان‌بندی دیگری فعال نیست، قلمرو پیش‌فرض «${defaultRealm.name}» فعال است.';

      final startOfDay = DateTime(now.year, now.month, now.day, 0, 0);
      final endsAt = nextSchedule?.scheduleStartDt ?? endOfToday;
      final totalDur = endsAt.difference(startOfDay);
      final elapsed = now.difference(startOfDay);
      final progress = totalDur.inSeconds > 0
          ? (elapsed.inSeconds / totalDur.inSeconds).clamp(0.0, 1.0)
          : 0.0;

      return ScheduledRealmState(
        realm: defaultRealm,
        schedule: RealmScheduleData(
          id: 'default_${defaultRealm.id}',
          zoneId: defaultRealm.id,
          daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
          startTime: '00:00',
          endTime: '23:59',
        ),
        startsAt: startOfDay,
        endsAt: endsAt,
        remaining: remaining.isNegative ? Duration.zero : remaining,
        progress: progress,
        explanation: explanation,
        isDefaultFallback: true,
      );
    }

    // 4. Free realm state
    return const FreeRealmState();
  }

  static ({RealmData realm, DateTime scheduleStartDt})? _findNextSchedule(
    DateTime now,
    List<RealmData> realms,
    List<RealmScheduleData> schedules,
  ) {
    final candidates = <({RealmData realm, DateTime scheduleStartDt})>[];

    // Check upcoming schedules for today and tomorrow
    for (var dayOffset = 0; dayOffset <= 1; dayOffset++) {
      final checkDate = now.add(Duration(days: dayOffset));
      final checkWeekday = checkDate.weekday;

      for (final s in schedules) {
        if (!s.daysOfWeek.contains(checkWeekday)) continue;
        final bounds = calculateScheduleBounds(
          now: checkDate,
          startTime: s.startTime,
          endTime: s.endTime,
        );
        if (bounds.startDt.isAfter(now)) {
          final realm = realms.firstWhere(
            (r) => r.id == s.zoneId,
            orElse: () => RealmData(
              id: s.zoneId,
              name: 'قلمرو',
              colorHex: '#6366F1',
              icon: '🎯',
              mode: RealmMode.normal,
            ),
          );
          candidates.add((realm: realm, scheduleStartDt: bounds.startDt));
        }
      }
    }

    if (candidates.isEmpty) return null;

    // B-06: Sort candidate schedules by start timestamp ascending
    candidates.sort((a, b) => a.scheduleStartDt.compareTo(b.scheduleStartDt));
    return candidates.first;
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _weekdayFa(int weekday) {
    switch (weekday) {
      case DateTime.saturday:
        return 'شنبه';
      case DateTime.sunday:
        return 'یکشنبه';
      case DateTime.monday:
        return 'دوشنبه';
      case DateTime.tuesday:
        return 'سه‌شنبه';
      case DateTime.wednesday:
        return 'چهارشنبه';
      case DateTime.thursday:
        return 'پنج‌شنبه';
      case DateTime.friday:
        return 'جمعه';
      default:
        return '';
    }
  }
}
