import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';

/// Priority 5: Evaluates default realm fallback (B-12, F-09).
class DefaultRealmLayer implements RealmResolutionLayer {
  const DefaultRealmLayer();

  @override
  ActiveRealmState? tryResolve(RealmContext ctx) {
    final defaultRealm = ctx.realms.where((r) => r.isDefault).firstOrNull;
    if (defaultRealm == null) return null;

    final now = ctx.now;
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final nextSchedule = ActiveRealmResolver.findNextSchedule(now, ctx.realms, ctx.schedules);

    final defaultSchedule = RealmScheduleData(
      id: 'default_${defaultRealm.id}',
      zoneId: defaultRealm.id,
      daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
      startTime: '00:00',
      endTime: '23:59',
    );

    return ScheduledRealmState(
      realm: defaultRealm,
      schedule: defaultSchedule,
      startsAt: startOfDay,
      endsAt: endOfDay,
      remaining: endOfDay.difference(now),
      progress: 1.0,
      explanation: nextSchedule != null
          ? 'چون خارج از زمان‌بندی هستی، قلمرو پیش‌فرض «${defaultRealm.name}» تا زمان شروع «${nextSchedule.realm.name}» (ساعت ${ActiveRealmResolver.formatTime(nextSchedule.scheduleStartDt)}) فعال است.'
          : 'چون هیچ زمان‌بندی فعالی نداری، قلمرو پیش‌فرض «${defaultRealm.name}» فعال است.',
      isDefaultFallback: true,
    );
  }
}
