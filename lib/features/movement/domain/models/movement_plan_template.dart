import 'dart:convert';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';

/// نوع و ماهیت جلسه در برنامه حرکت
enum MovementSessionType {
  simple,
  structured,
  repeating,
  event,
  retro,
}

/// نوع یادآور جلسه
enum MovementReminderType {
  none,
  preSession,
  morning,
}

/// مدل قالب برنامهٔ حرکت
class MovementPlanTemplate {
  const MovementPlanTemplate({
    required this.id,
    required this.activityKindId,
    this.activityKind,
    this.sessionType = 'repeating',
    this.goalJson,
    this.reminderType = 'none',
    this.reminderOffsetMin,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  final String id;
  final String activityKindId;
  final MovementActivityKind? activityKind;
  final String sessionType;
  final String? goalJson;
  final String reminderType;
  final int? reminderOffsetMin;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  Map<String, dynamic>? get parsedGoal {
    if (goalJson == null || goalJson!.trim().isEmpty) return null;
    try {
      return jsonDecode(goalJson!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  factory MovementPlanTemplate.fromMap(
    Map<String, dynamic> map, {
    MovementActivityKind? activityKind,
  }) {
    return MovementPlanTemplate(
      id: map['id'] as String,
      activityKindId: map['activityKindId'] as String,
      activityKind: activityKind,
      sessionType: (map['sessionType'] as String?) ?? 'repeating',
      goalJson: map['goalJson'] as String?,
      reminderType: (map['reminderType'] as String?) ?? 'none',
      reminderOffsetMin: map['reminderOffsetMin'] as int?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
      archivedAt: map['archivedAt'] != null ? DateTime.tryParse(map['archivedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activityKindId': activityKindId,
      'sessionType': sessionType,
      'goalJson': goalJson,
      'reminderType': reminderType,
      'reminderOffsetMin': reminderOffsetMin,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'archivedAt': archivedAt?.toUtc().toIso8601String(),
    };
  }

  MovementPlanTemplate copyWith({
    String? id,
    String? activityKindId,
    MovementActivityKind? activityKind,
    String? sessionType,
    String? goalJson,
    String? reminderType,
    int? reminderOffsetMin,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
  }) {
    return MovementPlanTemplate(
      id: id ?? this.id,
      activityKindId: activityKindId ?? this.activityKindId,
      activityKind: activityKind ?? this.activityKind,
      sessionType: sessionType ?? this.sessionType,
      goalJson: goalJson ?? this.goalJson,
      reminderType: reminderType ?? this.reminderType,
      reminderOffsetMin: reminderOffsetMin ?? this.reminderOffsetMin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }
}
