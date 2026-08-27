import 'package:ritmo/core/domain/realm/realm_mode.dart';
import 'package:ritmo/core/domain/realm/realm_state.dart';
import 'package:ritmo/core/domain/realm/resolution/composite_realm_resolver.dart';
import 'package:ritmo/core/domain/realm/resolution/realm_context.dart';
import 'package:ritmo/core/domain/realm/schedule_bounds.dart';
import 'package:ritmo/core/domain/realm/triggers/zone_trigger.dart';

export 'package:ritmo/core/domain/realm/budgets/zone_budget.dart';
export 'package:ritmo/core/domain/realm/budgets/zone_budget_repository.dart';
export 'package:ritmo/core/domain/realm/profiles/zone_profile.dart';
export 'package:ritmo/core/domain/realm/profiles/zone_profile_repository.dart';
export 'package:ritmo/core/domain/realm/realm_mode.dart';
export 'package:ritmo/core/domain/realm/realm_state.dart';
export 'package:ritmo/core/domain/realm/reports/zone_report_models.dart';
export 'package:ritmo/core/domain/realm/reports/zone_report_repository.dart';
export 'package:ritmo/core/domain/realm/resolution/composite_realm_resolver.dart';
export 'package:ritmo/core/domain/realm/resolution/realm_context.dart';
export 'package:ritmo/core/domain/realm/resolution/realm_resolution_layer.dart';
export 'package:ritmo/core/domain/realm/rituals/zone_ritual.dart';
export 'package:ritmo/core/domain/realm/rituals/zone_ritual_service.dart';
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

  /// Resolves the currently active realm state by delegating to [CompositeRealmResolver].
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
    final ctx = RealmContext(
      now: clock.now(),
      realms: realms,
      schedules: schedules,
      triggers: triggers,
      overrideRealmId: overrideRealmId,
      overrideUntilMs: overrideUntilMs,
      overrideStartedMs: overrideStartedMs,
      activeProfileId: activeProfileId,
      activeWifiSsid: activeWifiSsid,
      isCharging: isCharging,
      activeCalendarTags: activeCalendarTags,
    );

    return const CompositeRealmResolver().resolve(ctx);
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
