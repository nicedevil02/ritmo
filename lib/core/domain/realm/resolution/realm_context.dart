import 'package:flutter/foundation.dart';
import 'package:ritmo/core/domain/realm/realm_state.dart';
import 'package:ritmo/core/domain/realm/triggers/zone_trigger.dart';

/// Contextual data provided to the multi-layer realm resolution engine (F-09, F-10).
@immutable
class RealmContext {
  const RealmContext({
    required this.now,
    required this.realms,
    this.schedules = const [],
    this.triggers = const [],
    this.overrideRealmId,
    this.overrideUntilMs,
    this.overrideStartedMs,
    this.activeWifiSsid,
    this.isCharging = false,
    this.activeCalendarTags = const [],
  });

  final DateTime now;
  final List<RealmData> realms;
  final List<RealmScheduleData> schedules;
  final List<ZoneTrigger> triggers;
  final String? overrideRealmId;
  final int? overrideUntilMs;
  final int? overrideStartedMs;
  final String? activeWifiSsid;
  final bool isCharging;
  final List<String> activeCalendarTags;
}
