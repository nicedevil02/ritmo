import 'package:flutter/foundation.dart';

/// Target budget constraints for realm presence time (F-12).
@immutable
class ZoneBudget {
  const ZoneBudget({
    required this.zoneId,
    this.minMinutes,
    this.maxMinutes,
    this.period = 'WEEK',
    required this.updatedAt,
  });

  final String zoneId;
  final int? minMinutes;
  final int? maxMinutes;
  final String period; // 'WEEK' or 'DAY'
  final int updatedAt;

  Map<String, dynamic> toMap() => {
        'zoneId': zoneId,
        'minMinutes': minMinutes,
        'maxMinutes': maxMinutes,
        'period': period,
        'updatedAt': updatedAt,
      };

  factory ZoneBudget.fromMap(Map<String, dynamic> map) {
    return ZoneBudget(
      zoneId: map['zoneId'] as String,
      minMinutes: map['minMinutes'] as int?,
      maxMinutes: map['maxMinutes'] as int?,
      period: map['period'] as String? ?? 'WEEK',
      updatedAt: map['updatedAt'] as int? ?? 0,
    );
  }

  ZoneBudget copyWith({
    String? zoneId,
    int? minMinutes,
    int? maxMinutes,
    String? period,
    int? updatedAt,
  }) {
    return ZoneBudget(
      zoneId: zoneId ?? this.zoneId,
      minMinutes: minMinutes ?? this.minMinutes,
      maxMinutes: maxMinutes ?? this.maxMinutes,
      period: period ?? this.period,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
