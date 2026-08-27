import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';

/// Priority 4: Evaluates active time-scheduled realms with shortest-duration wins (ق-۹, F-09).
class ScheduleResolutionLayer implements RealmResolutionLayer {
  const ScheduleResolutionLayer();

  @override
  ActiveRealmState? tryResolve(RealmContext ctx) {
    final now = ctx.now;
    final currentWeekday = now.weekday;

    final activeMatchingSchedules = <({
      RealmData realm,
      RealmScheduleData schedule,
      int durationMin,
      DateTime startDt,
      DateTime endDt,
    })>[];

    for (final schedule in ctx.schedules) {
      if (!schedule.isEnabled) continue;
      if (schedule.profileId != null &&
          ctx.activeProfileId != null &&
          schedule.profileId != ctx.activeProfileId) {
        continue;
      }
      if (!schedule.daysOfWeek.contains(currentWeekday)) continue;

      final realm = ctx.realms.where((r) => r.id == schedule.zoneId).firstOrNull;
      if (realm == null) continue;

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

    return null;
  }
}
