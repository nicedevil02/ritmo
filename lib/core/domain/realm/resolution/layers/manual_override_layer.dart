import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';

/// Priority 1: Evaluates active manual override (ق-۷, B-07, F-09).
class ManualOverrideLayer implements RealmResolutionLayer {
  const ManualOverrideLayer();

  @override
  ActiveRealmState? tryResolve(RealmContext ctx) {
    final now = ctx.now;
    final nowMs = now.millisecondsSinceEpoch;

    if (ctx.overrideRealmId != null &&
        ctx.overrideRealmId!.isNotEmpty &&
        ctx.overrideUntilMs != null &&
        nowMs < ctx.overrideUntilMs!) {
      final overrideRealm = ctx.realms.firstWhere(
        (r) => r.id == ctx.overrideRealmId,
        orElse: () => RealmData(
          id: ctx.overrideRealmId!,
          name: 'قلمرو دستی',
          colorHex: '#6366F1',
          icon: '🎯',
          mode: RealmMode.normal,
        ),
      );

      final expireAt = DateTime.fromMillisecondsSinceEpoch(ctx.overrideUntilMs!);
      final remaining = expireAt.difference(now);

      final double progress;
      final DateTime? startedAt;
      if (ctx.overrideStartedMs != null &&
          ctx.overrideStartedMs! > 0 &&
          ctx.overrideStartedMs! < ctx.overrideUntilMs!) {
        startedAt = DateTime.fromMillisecondsSinceEpoch(ctx.overrideStartedMs!);
        final total = ctx.overrideUntilMs! - ctx.overrideStartedMs!;
        final elapsed = nowMs - ctx.overrideStartedMs!;
        progress = total <= 0 ? 1.0 : (elapsed / total).clamp(0.0, 1.0);
      } else {
        startedAt = null;
        progress = 1.0;
      }

      final nextSchedule = ActiveRealmResolver.findNextSchedule(now, ctx.realms, ctx.schedules);

      final explanation =
          'چون خودت تا ساعت ${ActiveRealmResolver.formatTime(expireAt)} این قلمرو را به صورت دستی فعال کردی.';

      return ManualRealmState(
        realm: overrideRealm,
        expireAt: expireAt,
        startedAt: startedAt,
        remaining: remaining.isNegative ? Duration.zero : remaining,
        progress: progress,
        explanation: explanation,
        nextRealmName: nextSchedule?.realm.name,
        nextRealmTimeStr: nextSchedule != null
            ? ActiveRealmResolver.formatTime(nextSchedule.scheduleStartDt)
            : null,
      );
    }

    return null;
  }
}
