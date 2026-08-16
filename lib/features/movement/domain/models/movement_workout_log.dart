import 'dart:convert';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';

/// منبع ثبت لاگ تمرین
enum MovementLogSource {
  live,
  quick,
  retro,
}

/// مدل لاگ و تاریخچهٔ ثبت تمرین
class MovementWorkoutLog {
  const MovementWorkoutLog({
    required this.id,
    this.occurrenceId,
    required this.activityKindId,
    this.activityKind,
    required this.dateIso,
    this.startTime,
    required this.durationSec,
    this.metricJson,
    this.feeling,
    this.note,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? occurrenceId;
  final String activityKindId;
  final MovementActivityKind? activityKind;
  final String dateIso;
  final String? startTime;
  final int durationSec;
  final String? metricJson;
  final String? feeling;
  final String? note;

  /// منبع ثبت: live, quick, retro
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic>? get parsedMetrics {
    if (metricJson == null || metricJson!.trim().isEmpty) return null;
    try {
      return jsonDecode(metricJson!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? get metricMap => parsedMetrics;

  factory MovementWorkoutLog.fromMap(
    Map<String, dynamic> map, {
    MovementActivityKind? activityKind,
  }) {
    return MovementWorkoutLog(
      id: map['id'] as String,
      occurrenceId: map['occurrenceId'] as String?,
      activityKindId: map['activityKindId'] as String,
      activityKind: activityKind,
      dateIso: map['dateIso'] as String,
      startTime: map['startTime'] as String?,
      durationSec: (map['durationSec'] as int?) ?? 0,
      metricJson: map['metricJson'] as String?,
      feeling: map['feeling'] as String?,
      note: map['note'] as String?,
      source: (map['source'] as String?) ?? 'quick',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'occurrenceId': occurrenceId,
      'activityKindId': activityKindId,
      'dateIso': dateIso,
      'startTime': startTime,
      'durationSec': durationSec,
      'metricJson': metricJson,
      'feeling': feeling,
      'note': note,
      'source': source,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  MovementWorkoutLog copyWith({
    String? id,
    String? occurrenceId,
    String? activityKindId,
    MovementActivityKind? activityKind,
    String? dateIso,
    String? startTime,
    int? durationSec,
    String? metricJson,
    String? feeling,
    String? note,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MovementWorkoutLog(
      id: id ?? this.id,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      activityKindId: activityKindId ?? this.activityKindId,
      activityKind: activityKind ?? this.activityKind,
      dateIso: dateIso ?? this.dateIso,
      startTime: startTime ?? this.startTime,
      durationSec: durationSec ?? this.durationSec,
      metricJson: metricJson ?? this.metricJson,
      feeling: feeling ?? this.feeling,
      note: note ?? this.note,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
