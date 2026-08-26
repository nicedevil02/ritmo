import 'package:flutter/foundation.dart';

/// Supported automation trigger kinds for Time Realms (F-08, F-10).
enum TriggerKind {
  wifiSsid,
  charger,
  calendarTag,
  geofence,
  bluetooth,
  nfc;

  String toRaw() => switch (this) {
        TriggerKind.wifiSsid => 'WIFI_SSID',
        TriggerKind.charger => 'CHARGER',
        TriggerKind.calendarTag => 'CALENDAR_TAG',
        TriggerKind.geofence => 'GEOFENCE',
        TriggerKind.bluetooth => 'BLUETOOTH',
        TriggerKind.nfc => 'NFC',
      };

  static TriggerKind fromRaw(String raw) => switch (raw.toUpperCase().trim()) {
        'WIFI_SSID' => TriggerKind.wifiSsid,
        'CHARGER' => TriggerKind.charger,
        'CALENDAR_TAG' => TriggerKind.calendarTag,
        'GEOFENCE' => TriggerKind.geofence,
        'BLUETOOTH' => TriggerKind.bluetooth,
        'NFC' => TriggerKind.nfc,
        _ => TriggerKind.wifiSsid,
      };
}

/// Represents an automated condition that activates a realm (F-08).
@immutable
class ZoneTrigger {
  const ZoneTrigger({
    required this.id,
    required this.zoneId,
    required this.kind,
    required this.value,
    this.priority = 0,
    this.isEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String zoneId;
  final TriggerKind kind;
  final String value;
  final int priority;
  final bool isEnabled;
  final int createdAt;
  final int updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'zoneId': zoneId,
        'kind': kind.toRaw(),
        'value': value,
        'priority': priority,
        'isEnabled': isEnabled ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory ZoneTrigger.fromMap(Map<String, dynamic> map) {
    return ZoneTrigger(
      id: map['id'] as String,
      zoneId: map['zoneId'] as String,
      kind: TriggerKind.fromRaw(map['kind'] as String? ?? 'WIFI_SSID'),
      value: map['value'] as String? ?? '',
      priority: map['priority'] as int? ?? 0,
      isEnabled: (map['isEnabled'] as int? ?? 1) == 1,
      createdAt: map['createdAt'] as int? ?? 0,
      updatedAt: map['updatedAt'] as int? ?? 0,
    );
  }

  ZoneTrigger copyWith({
    String? id,
    String? zoneId,
    TriggerKind? kind,
    String? value,
    int? priority,
    bool? isEnabled,
    int? createdAt,
    int? updatedAt,
  }) {
    return ZoneTrigger(
      id: id ?? this.id,
      zoneId: zoneId ?? this.zoneId,
      kind: kind ?? this.kind,
      value: value ?? this.value,
      priority: priority ?? this.priority,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
