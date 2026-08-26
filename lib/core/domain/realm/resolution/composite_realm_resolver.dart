import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/core/domain/realm/resolution/layers/calendar_tag_layer.dart';
import 'package:ritmo/core/domain/realm/resolution/layers/default_realm_layer.dart';
import 'package:ritmo/core/domain/realm/resolution/layers/manual_override_layer.dart';
import 'package:ritmo/core/domain/realm/resolution/layers/schedule_resolution_layer.dart';
import 'package:ritmo/core/domain/realm/resolution/layers/trigger_resolution_layer.dart';

/// Priority-based composite realm resolution engine (F-09).
///
/// Executes the resolution layers in decreasing priority:
/// 1. Manual override (`ManualOverrideLayer`)
/// 2. Hardware / Network triggers (`TriggerResolutionLayer`)
/// 3. Calendar events & tags (`CalendarTagLayer`)
/// 4. Day schedule bounds (`ScheduleResolutionLayer`)
/// 5. Default realm fallback (`DefaultRealmLayer`)
/// 6. Free state fallback (`FreeRealmState`)
class CompositeRealmResolver {
  const CompositeRealmResolver({
    this.layers = const [
      ManualOverrideLayer(),
      TriggerResolutionLayer(),
      CalendarTagLayer(),
      ScheduleResolutionLayer(),
      DefaultRealmLayer(),
    ],
  });

  final List<RealmResolutionLayer> layers;

  Future<ActiveRealmState> resolve(RealmContext ctx) async {
    for (final layer in layers) {
      final result = await layer.tryResolve(ctx);
      if (result != null) return result;
    }

    final nextSchedule = ActiveRealmResolver.findNextSchedule(ctx.now, ctx.realms, ctx.schedules);
    final explanation = nextSchedule != null
        ? 'الان در زمان آزاد هستی تا ساعت ${ActiveRealmResolver.formatTime(nextSchedule.scheduleStartDt)} که قلمرو «${nextSchedule.realm.name}» شروع می‌شود.'
        : 'الان در زمان آزاد هستی و هیچ قلمرویی فعال نیست.';

    return FreeRealmState(explanation: explanation);
  }
}
