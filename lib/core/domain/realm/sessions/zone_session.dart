/// Origin source that triggered activation of a zone session.
enum ZoneSource {
  schedule,
  manual,
  defaultRealm,
  wifi,
  geofence,
  calendar,
  bluetooth,
  nfc;

  String toRaw() => switch (this) {
    ZoneSource.schedule => 'SCHEDULE',
    ZoneSource.manual => 'MANUAL',
    ZoneSource.defaultRealm => 'DEFAULT',
    ZoneSource.wifi => 'WIFI',
    ZoneSource.geofence => 'GEOFENCE',
    ZoneSource.calendar => 'CALENDAR',
    ZoneSource.bluetooth => 'BLUETOOTH',
    ZoneSource.nfc => 'NFC',
  };

  static ZoneSource fromRaw(String? raw) {
    return switch (raw?.toUpperCase().trim()) {
      'MANUAL' => ZoneSource.manual,
      'DEFAULT' => ZoneSource.defaultRealm,
      'WIFI' => ZoneSource.wifi,
      'GEOFENCE' => ZoneSource.geofence,
      'CALENDAR' => ZoneSource.calendar,
      'BLUETOOTH' => ZoneSource.bluetooth,
      'NFC' => ZoneSource.nfc,
      _ => ZoneSource.schedule,
    };
  }
}

/// Reason why an active zone session was closed.
enum ZoneEndReason {
  completed,
  userEnded,
  overridden,
  system,
  abandoned;

  String toRaw() => switch (this) {
    ZoneEndReason.completed => 'COMPLETED',
    ZoneEndReason.userEnded => 'USER_ENDED',
    ZoneEndReason.overridden => 'OVERRIDDEN',
    ZoneEndReason.system => 'SYSTEM',
    ZoneEndReason.abandoned => 'ABANDONED',
  };

  static ZoneEndReason fromRaw(String? raw) {
    return switch (raw?.toUpperCase().trim()) {
      'USER_ENDED' => ZoneEndReason.userEnded,
      'OVERRIDDEN' => ZoneEndReason.overridden,
      'SYSTEM' => ZoneEndReason.system,
      'ABANDONED' => ZoneEndReason.abandoned,
      _ => ZoneEndReason.completed,
    };
  }
}

/// Represents a single recorded period of user presence in a time realm (F-01).
class ZoneSession {
  const ZoneSession({
    required this.id,
    required this.zoneId,
    required this.startedAt,
    this.endedAt,
    this.plannedEndAt,
    this.source = ZoneSource.schedule,
    this.endReason,
    required this.createdAt,
  });

  final String id;
  final String zoneId;
  final int startedAt;
  final int? endedAt;
  final int? plannedEndAt;
  final ZoneSource source;
  final ZoneEndReason? endReason;
  final int createdAt;

  /// Whether this session is currently active/open (endedAt IS NULL).
  bool get isOpen => endedAt == null;

  /// Duration of the session in milliseconds (actual or up to [nowMs] if open).
  int durationMs({int? nowMs}) {
    final end = endedAt ?? (nowMs ?? DateTime.now().millisecondsSinceEpoch);
    final diff = end - startedAt;
    return diff > 0 ? diff : 0;
  }

  /// Duration of the session in minutes.
  int durationMinutes({int? nowMs}) => durationMs(nowMs: nowMs) ~/ 60000;

  factory ZoneSession.fromMap(Map<String, dynamic> map) {
    return ZoneSession(
      id: map['id'] as String,
      zoneId: map['zoneId'] as String,
      startedAt: map['startedAt'] as int,
      endedAt: map['endedAt'] as int?,
      plannedEndAt: map['plannedEndAt'] as int?,
      source: ZoneSource.fromRaw(map['source'] as String?),
      endReason: map['endReason'] != null
          ? ZoneEndReason.fromRaw(map['endReason'] as String)
          : null,
      createdAt: map['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'zoneId': zoneId,
      'startedAt': startedAt,
      'endedAt': endedAt,
      'plannedEndAt': plannedEndAt,
      'source': source.toRaw(),
      'endReason': endReason?.toRaw(),
      'createdAt': createdAt,
    };
  }

  ZoneSession copyWith({
    String? id,
    String? zoneId,
    int? startedAt,
    int? endedAt,
    int? plannedEndAt,
    ZoneSource? source,
    ZoneEndReason? endReason,
    int? createdAt,
  }) {
    return ZoneSession(
      id: id ?? this.id,
      zoneId: zoneId ?? this.zoneId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      plannedEndAt: plannedEndAt ?? this.plannedEndAt,
      source: source ?? this.source,
      endReason: endReason ?? this.endReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
