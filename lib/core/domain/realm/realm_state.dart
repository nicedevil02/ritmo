import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/realm/realm_mode.dart';
import 'package:ritmo/core/domain/realm/rituals/zone_ritual.dart';
import 'package:ritmo/core/domain/realm/triggers/zone_trigger.dart';

class RealmData {
  const RealmData({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.icon,
    required this.mode,
    this.isDefault = false,
    this.hideOtherRealms = false,
    this.ritualOnEnter,
    this.ritualOnExit,
    this.createdAt,
  });

  final String id;
  final String name;
  final String colorHex;
  final String icon;
  final RealmMode mode;
  final bool isDefault;
  final bool hideOtherRealms;
  final ZoneRitualConfig? ritualOnEnter;
  final ZoneRitualConfig? ritualOnExit;
  final int? createdAt;

  factory RealmData.fromMap(Map<String, dynamic> map) {
    return RealmData(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'قلمرو',
      colorHex: map['color'] as String? ?? '#6366F1',
      icon: map['icon'] as String? ?? '🎯',
      mode: parseRealmMode(map['mode'] as String?),
      isDefault: (map['isDefault'] as int? ?? 0) == 1,
      hideOtherRealms: (map['hideOtherRealms'] as int? ?? 0) == 1,
      ritualOnEnter: ZoneRitualConfig.fromJson(map['ritualOnEnter'] as String?),
      ritualOnExit: ZoneRitualConfig.fromJson(map['ritualOnExit'] as String?),
      createdAt: map['createdAt'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': colorHex,
      'icon': icon,
      'mode': realmModeToRaw(mode),
      'isDefault': isDefault ? 1 : 0,
      'hideOtherRealms': hideOtherRealms ? 1 : 0,
      'ritualOnEnter': ritualOnEnter?.toJson(),
      'ritualOnExit': ritualOnExit?.toJson(),
      'createdAt': createdAt ?? DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Color parseColor({Color fallback = const Color(0xFF6366F1)}) {
    try {
      var hex = colorHex.replaceAll('#', '').trim();
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }
}

class RealmScheduleData {
  const RealmScheduleData({
    required this.id,
    required this.zoneId,
    required this.daysOfWeek,
    required this.startTime,
    required this.endTime,
    this.profileId,
    this.isEnabled = true,
    this.createdAt,
  });

  final String id;
  final String zoneId;
  final Set<int> daysOfWeek; // 1: Mon ... 7: Sun
  final String startTime; // "HH:mm"
  final String endTime;   // "HH:mm"
  final String? profileId;
  final bool isEnabled;
  final int? createdAt;

  factory RealmScheduleData.fromMap(Map<String, dynamic> map) {
    final daysStr = map['daysOfWeek'] as String? ?? '';
    final days = daysStr
        .split(',')
        .map((d) => int.tryParse(d.trim()) ?? 0)
        .where((d) => d >= 1 && d <= 7)
        .toSet();

    return RealmScheduleData(
      id: map['id'] as String,
      zoneId: map['zoneId'] as String,
      daysOfWeek: days,
      startTime: map['startTime'] as String? ?? '00:00',
      endTime: map['endTime'] as String? ?? '23:59',
      profileId: map['profileId'] as String?,
      isEnabled: (map['isEnabled'] as int? ?? 1) == 1,
      createdAt: map['createdAt'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'zoneId': zoneId,
      'daysOfWeek': daysOfWeek.join(','),
      'startTime': startTime,
      'endTime': endTime,
      'profileId': profileId,
      'isEnabled': isEnabled ? 1 : 0,
      'createdAt': createdAt ?? DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

sealed class ActiveRealmState {
  const ActiveRealmState();

  bool get isActive =>
      this is ScheduledRealmState ||
      this is ManualRealmState ||
      this is TriggeredRealmState;
  bool get isFree => this is FreeRealmState;
}

final class ScheduledRealmState extends ActiveRealmState {
  const ScheduledRealmState({
    required this.realm,
    required this.schedule,
    required this.startsAt,
    required this.endsAt,
    required this.remaining,
    required this.progress,
    required this.explanation,
    this.isDefaultFallback = false,
  });

  final RealmData realm;
  final RealmScheduleData schedule;
  final DateTime startsAt;
  final DateTime endsAt;
  final Duration remaining;
  final double progress; // 0.0 to 1.0
  final String explanation;
  final bool isDefaultFallback;
}

final class ManualRealmState extends ActiveRealmState {
  const ManualRealmState({
    required this.realm,
    required this.expireAt,
    this.startedAt,
    required this.remaining,
    required this.progress,
    required this.explanation,
    this.nextRealmName,
    this.nextRealmTimeStr,
  });

  final RealmData realm;
  final DateTime expireAt;
  final DateTime? startedAt;
  final Duration remaining;
  final double progress; // 0.0 to 1.0
  final String explanation;
  final String? nextRealmName;
  final String? nextRealmTimeStr;
}

/// Represents an automated realm activated by a hardware or contextual trigger (F-08, F-10).
final class TriggeredRealmState extends ActiveRealmState {
  const TriggeredRealmState({
    required this.realm,
    required this.trigger,
    required this.startsAt,
    this.endsAt,
    required this.explanation,
  });

  final RealmData realm;
  final ZoneTrigger trigger;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String explanation;
}

final class FreeRealmState extends ActiveRealmState {
  const FreeRealmState({
    this.explanation = 'الان در زمان آزاد هستی و هیچ قلمرویی فعال نیست.',
  });
  final String explanation;
}

final class RealmErrorState extends ActiveRealmState {
  const RealmErrorState(this.error);
  final Object error;
}

extension ActiveRealmStateX on ActiveRealmState {
  RealmData? get realmOrNull => switch (this) {
    ScheduledRealmState(:final realm) => realm,
    ManualRealmState(:final realm) => realm,
    TriggeredRealmState(:final realm) => realm,
    FreeRealmState() => null,
    RealmErrorState() => null,
  };

  RealmMode get effectiveMode => realmOrNull?.mode ?? RealmMode.normal;
}
