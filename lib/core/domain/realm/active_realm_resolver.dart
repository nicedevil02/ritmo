import 'package:ritmo/core/domain/realm/realm_mode.dart';
import 'package:ritmo/core/domain/realm/realm_state.dart';
import 'package:ritmo/core/domain/realm/schedule_bounds.dart';
import 'package:ritmo/core/domain/realm/triggers/zone_trigger.dart';

export 'package:ritmo/core/domain/realm/budgets/zone_budget.dart';
export 'package:ritmo/core/domain/realm/budgets/zone_budget_repository.dart';
export 'package:ritmo/core/domain/realm/profiles/zone_profile.dart';
export 'package:ritmo/core/domain/realm/profiles/zone_profile_repository.dart';
export 'package:ritmo/core/domain/realm/realm_mode.dart';
export 'package:ritmo/core/domain/realm/realm_state.dart';
export 'package:ritmo/core/domain/realm/resolution/composite_realm_resolver.dart';
export 'package:ritmo/core/domain/realm/resolution/realm_context.dart';
export 'package:ritmo/core/domain/realm/resolution/realm_resolution_layer.dart';
export 'package:ritmo/core/domain/realm/schedule_bounds.dart';
export 'package:ritmo/core/domain/realm/triggers/zone_trigger.dart';
export 'package:ritmo/core/domain/realm/triggers/zone_trigger_repository.dart';

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
    List<ZoneTrigger> triggers = const [],
    String? overrideRealmId,
    int? overrideUntilMs,
    int? overrideStartedMs,
    String? activeProfileId,
    String? activeWifiSsid,
    bool isCharging = false,
    List<String> activeCalendarTags = const [],
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
      final nextSchedule = findNextSchedule(now, realms, schedules);

      final explanation =
          'چون خودت تا ساعت ${formatTime(expireAt)} این قلمرو را به صورت دستی فعال کردی.';

      return ManualRealmState(
        realm: overrideRealm,
        expireAt: expireAt,
        startedAt: startedAt,
        remaining: remaining.isNegative ? Duration.zero : remaining,
        progress: progress,
        explanation: explanation,
        nextRealmName: nextSchedule?.realm.name,
        nextRealmTimeStr: nextSchedule != null
            ? formatTime(nextSchedule.scheduleStartDt)
            : null,
      );
    }

    // 2. Check hardware / network triggers (F-08, F-10)
    final enabledTriggers = triggers.where((t) => t.isEnabled).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final trigger in enabledTriggers) {
      final realm = realms.where((r) => r.id == trigger.zoneId).firstOrNull;
      if (realm == null) continue;

      bool isMatched = false;
      String reason = '';

      if (trigger.kind == TriggerKind.wifiSsid && activeWifiSsid != null && activeWifiSsid.isNotEmpty) {
        final current = activeWifiSsid.replaceAll('"', '').trim().toLowerCase();
        final target = trigger.value.replaceAll('"', '').trim().toLowerCase();
        if (current == target || current.contains(target)) {
          isMatched = true;
          reason = 'به دلیل اتصال خودکار به شبکه وای‌فای «$activeWifiSsid».';
        }
      } else if (trigger.kind == TriggerKind.charger && isCharging) {
        final trimmed = trigger.value.trim();
        if (trimmed.isEmpty || trimmed.toUpperCase() == 'ALL_DAY') {
          isMatched = true;
        } else {
          final parts = trimmed.split('-');
          if (parts.length == 2) {
            final startP = parts[0].trim().split(':');
            final endP = parts[1].trim().split(':');
            final sMin = (int.tryParse(startP[0]) ?? 0) * 60 + (int.tryParse(startP[1]) ?? 0);
            final eMin = (int.tryParse(endP[0]) ?? 0) * 60 + (int.tryParse(endP[1]) ?? 0);
            final nMin = now.hour * 60 + now.minute;
            isMatched = sMin <= eMin ? (nMin >= sMin && nMin < eMin) : (nMin >= sMin || nMin < eMin);
          }
        }
        if (isMatched) reason = 'به دلیل اتصال به شارژر.';
      } else if (trigger.kind == TriggerKind.calendarTag && activeCalendarTags.isNotEmpty) {
        final target = trigger.value.trim().toLowerCase();
        if (activeCalendarTags.any((t) => t.trim().toLowerCase().contains(target))) {
          isMatched = true;
          reason = 'به دلیل رویداد تقویم با برچسب «${trigger.value}».';
        }
      }

      if (isMatched) {
        return TriggeredRealmState(
          realm: realm,
          trigger: trigger,
          startsAt: now,
          explanation: reason,
        );
      }
    }

    // 3. Check scheduled realms
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
      if (!schedule.isEnabled) continue;
      if (schedule.profileId != null &&
          activeProfileId != null &&
          schedule.profileId != activeProfileId) {
        continue;
      }
      if (!schedule.daysOfWeek.contains(currentWeekday)) continue;

      final realm = realms.firstWhere(
        (r) => r.id == schedule.zoneId,
        orElse: () => RealmData(
          id: schedule.zoneId,
          name: 'قلمرو',
          colorHex: '#6366F1',
          icon: '🎯',
          mode: RealmMode.normal,
        ),
      );

      final bounds = calculateScheduleBounds(
        now: now,
        startTime: schedule.startTime,
        endTime: schedule.endTime,
      );

      if (now.isAfter(bounds.startDt) && now.isBefore(bounds.endDt) ||
          now.isAtSameMomentAs(bounds.startDt)) {
        final durationMin = bounds.endDt.difference(bounds.startDt).inMinutes;
        activeMatchingSchedules.add((
          realm: realm,
          schedule: schedule,
          durationMin: durationMin,
          startDt: bounds.startDt,
          endDt: bounds.endDt,
        ));
      }
    }

    if (activeMatchingSchedules.isNotEmpty) {
      // Sort by shortest duration (ق-۹) then by creation order
      activeMatchingSchedules.sort((a, b) {
        final durCmp = a.durationMin.compareTo(b.durationMin);
        if (durCmp != 0) return durCmp;
        return (a.realm.createdAt ?? 0).compareTo(b.realm.createdAt ?? 0);
      });

      final winning = activeMatchingSchedules.first;
      final remaining = winning.endDt.difference(now);
      final totalDuration = winning.endDt.difference(winning.startDt);
      final elapsed = now.difference(winning.startDt);
      final progress = totalDuration.inSeconds <= 0
          ? 1.0
          : (elapsed.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0);

      final explanation =
          'چون طبق زمان‌بندی «${winning.schedule.startTime} تا ${winning.schedule.endTime}» فعال است.';

      return ScheduledRealmState(
        realm: winning.realm,
        schedule: winning.schedule,
        startsAt: winning.startDt,
        endsAt: winning.endDt,
        remaining: remaining.isNegative ? Duration.zero : remaining,
        progress: progress,
        explanation: explanation,
      );
    }

    // 4. Check default realm fallback (B-12)
    final defaultRealmCandidates = realms.where((r) => r.isDefault).toList();
    if (defaultRealmCandidates.isNotEmpty) {
      final defaultRealm = defaultRealmCandidates.first;
      final nextSchedule = findNextSchedule(now, realms, schedules, activeProfileId: activeProfileId);

      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final remaining = nextSchedule != null
          ? nextSchedule.scheduleStartDt.difference(now)
          : endOfToday.difference(now);

      final explanation = nextSchedule != null
          ? 'چون خارج از زمان‌بندی هستی، قلمرو پیش‌فرض «${defaultRealm.name}» تا شروع قلمرو بعدی (${formatTime(nextSchedule.scheduleStartDt)}) فعال است.'
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

    // 5. Free realm state
    return const FreeRealmState();
  }

  static ({RealmData realm, DateTime scheduleStartDt})? findNextSchedule(
    DateTime now,
    List<RealmData> realms,
    List<RealmScheduleData> schedules, {
    String? activeProfileId,
  }) {
    final candidates = <({RealmData realm, DateTime scheduleStartDt})>[];

    // Check upcoming schedules for today and tomorrow
    for (var dayOffset = 0; dayOffset <= 1; dayOffset++) {
      final checkDate = now.add(Duration(days: dayOffset));
      final checkWeekday = checkDate.weekday;

      for (final s in schedules) {
        if (!s.isEnabled) continue;
        if (s.profileId != null &&
            activeProfileId != null &&
            s.profileId != activeProfileId) {
          continue;
        }
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

  static String formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String weekdayFa(int weekday) {
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
