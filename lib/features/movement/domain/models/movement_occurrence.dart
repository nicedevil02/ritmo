import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';

/// وضعیت رخداد جلسه
enum MovementOccurrenceStatus {
  planned,
  inProgress,
  completed,
  partial,
  skipped,
  moved,
  late,
  restDay;

  static MovementOccurrenceStatus fromString(String val) {
    return MovementOccurrenceStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => MovementOccurrenceStatus.planned,
    );
  }
}

/// منشأ ایجاد رخداد
enum MovementOrigin {
  template,
  oneOff,
  quickStart,
  retro,
  strength;

  static MovementOrigin fromString(String val) {
    return MovementOrigin.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => MovementOrigin.template,
    );
  }
}

/// مدل رخداد جلسهٔ حرکتی
class MovementOccurrence {
  const MovementOccurrence({
    required this.id,
    required this.activityKindId,
    this.activityKind,
    this.templateId,
    this.scheduleId,
    required this.dateIso,
    this.startTime,
    required this.status,
    this.goalType,
    this.goalValue,
    this.goalUnit,
    this.movedToDateIso,
    required this.origin,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String activityKindId;
  final MovementActivityKind? activityKind;
  final String? templateId;
  final String? scheduleId;
  final String dateIso; // YYYY-MM-DD
  final String? startTime; // HH:mm
  final MovementOccurrenceStatus status;
  final String? goalType; // duration, distance, volume, steps
  final double? goalValue;
  final String? goalUnit; // min, km, m, reps
  final String? movedToDateIso;
  final MovementOrigin origin;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => status == MovementOccurrenceStatus.completed;
  bool get isPlanned => status == MovementOccurrenceStatus.planned;
  bool get isInProgress => status == MovementOccurrenceStatus.inProgress;
  bool get isLate => status == MovementOccurrenceStatus.late;
  bool get isRestDay => status == MovementOccurrenceStatus.restDay;

  String get displayName => activityKind?.nameFa ?? 'تمرین حرکتی';

  MovementOccurrence copyWith({
    String? id,
    String? activityKindId,
    MovementActivityKind? activityKind,
    String? templateId,
    String? scheduleId,
    String? dateIso,
    String? startTime,
    MovementOccurrenceStatus? status,
    String? goalType,
    double? goalValue,
    String? goalUnit,
    String? movedToDateIso,
    MovementOrigin? origin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MovementOccurrence(
      id: id ?? this.id,
      activityKindId: activityKindId ?? this.activityKindId,
      activityKind: activityKind ?? this.activityKind,
      templateId: templateId ?? this.templateId,
      scheduleId: scheduleId ?? this.scheduleId,
      dateIso: dateIso ?? this.dateIso,
      startTime: startTime ?? this.startTime,
      status: status ?? this.status,
      goalType: goalType ?? this.goalType,
      goalValue: goalValue ?? this.goalValue,
      goalUnit: goalUnit ?? this.goalUnit,
      movedToDateIso: movedToDateIso ?? this.movedToDateIso,
      origin: origin ?? this.origin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MovementOccurrence.fromMap(
    Map<String, dynamic> map, {
    MovementActivityKind? activityKind,
  }) {
    return MovementOccurrence(
      id: map['id'] as String,
      activityKindId: map['activityKindId'] as String,
      activityKind: activityKind,
      templateId: map['templateId'] as String?,
      scheduleId: map['scheduleId'] as String?,
      dateIso: map['dateIso'] as String,
      startTime: map['startTime'] as String?,
      status: MovementOccurrenceStatus.fromString(
        map['status'] as String? ?? 'planned',
      ),
      goalType: map['goalType'] as String?,
      goalValue: (map['goalValue'] as num?)?.toDouble(),
      goalUnit: map['goalUnit'] as String?,
      movedToDateIso: map['movedToDateIso'] as String?,
      origin: MovementOrigin.fromString(map['origin'] as String? ?? 'template'),
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activityKindId': activityKindId,
      'templateId': templateId,
      'scheduleId': scheduleId,
      'dateIso': dateIso,
      'startTime': startTime,
      'status': status.name,
      'goalType': goalType,
      'goalValue': goalValue,
      'goalUnit': goalUnit,
      'movedToDateIso': movedToDateIso,
      'origin': origin.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
