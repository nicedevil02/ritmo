import 'package:ritmo/core/domain/realm/realm_state.dart';
import 'package:ritmo/core/domain/realm/resolution/realm_context.dart';
import 'package:ritmo/core/domain/realm/resolution/realm_resolution_layer.dart';
import 'package:ritmo/core/domain/realm/triggers/zone_trigger.dart';

/// Priority 3: Evaluates active calendar event tags against realm triggers (F-09, F-10).
class CalendarTagLayer implements RealmResolutionLayer {
  const CalendarTagLayer();

  @override
  ActiveRealmState? tryResolve(RealmContext ctx) {
    if (ctx.activeCalendarTags.isEmpty) return null;

    final calendarTriggers = ctx.triggers
        .where((t) => t.isEnabled && t.kind == TriggerKind.calendarTag)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final trigger in calendarTriggers) {
      final realm = ctx.realms.where((r) => r.id == trigger.zoneId).firstOrNull;
      if (realm == null) continue;

      final targetTag = trigger.value.trim().toLowerCase();
      final isMatched = ctx.activeCalendarTags.any(
        (tag) => tag.trim().toLowerCase().contains(targetTag),
      );

      if (isMatched) {
        return TriggeredRealmState(
          realm: realm,
          trigger: trigger,
          startsAt: ctx.now,
          explanation: 'به دلیل رویداد تقویم با برچسب «${trigger.value}».',
        );
      }
    }

    return null;
  }
}
