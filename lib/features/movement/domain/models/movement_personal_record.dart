import 'package:flutter/foundation.dart';

/// مدل رکورد شخصی واقعی (Personal Record) در ماژول حرکت (Gate 5)
@immutable
class MovementPersonalRecord {
  const MovementPersonalRecord({
    required this.id,
    this.activityKindId,
    this.exerciseId,
    required this.recordType,
    required this.value,
    required this.unit,
    required this.achievedAt,
    this.sourceId,
    this.exerciseOrActivityNameFa,
    this.isEstimated = false,
  });

  final String id;
  final String? activityKindId;
  final String? exerciseId;
  final String
  recordType; // e.g. max_weight, max_reps, max_duration, max_distance
  final double value;
  final String unit;
  final DateTime achievedAt;
  final String? sourceId;
  final String? exerciseOrActivityNameFa;
  final bool isEstimated;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activityKindId': activityKindId,
      'exerciseId': exerciseId,
      'recordType': recordType,
      'value': value,
      'unit': unit,
      'achievedAt': achievedAt.toUtc().toIso8601String(),
      'sourceId': sourceId,
    };
  }

  factory MovementPersonalRecord.fromMap(Map<String, dynamic> map) {
    return MovementPersonalRecord(
      id: map['id'] as String,
      activityKindId: map['activityKindId'] as String?,
      exerciseId: map['exerciseId'] as String?,
      recordType: map['recordType'] as String,
      value: (map['value'] as num).toDouble(),
      unit: map['unit'] as String,
      achievedAt: DateTime.parse(map['achievedAt'] as String).toLocal(),
      sourceId: map['sourceId'] as String?,
      isEstimated: false,
    );
  }

  MovementPersonalRecord copyWith({
    String? id,
    String? activityKindId,
    String? exerciseId,
    String? recordType,
    double? value,
    String? unit,
    DateTime? achievedAt,
    String? sourceId,
    String? exerciseOrActivityNameFa,
    bool? isEstimated,
  }) {
    return MovementPersonalRecord(
      id: id ?? this.id,
      activityKindId: activityKindId ?? this.activityKindId,
      exerciseId: exerciseId ?? this.exerciseId,
      recordType: recordType ?? this.recordType,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      achievedAt: achievedAt ?? this.achievedAt,
      sourceId: sourceId ?? this.sourceId,
      exerciseOrActivityNameFa:
          exerciseOrActivityNameFa ?? this.exerciseOrActivityNameFa,
      isEstimated: isEstimated ?? this.isEstimated,
    );
  }
}
