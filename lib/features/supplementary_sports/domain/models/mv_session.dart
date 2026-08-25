import 'mv_enums.dart';

/// Unified Live & Logged Workout / Movement Session.
///
/// Single Source of Truth for live tracking and historical session executions.
class MvSession {
  final String id;
  final String kindCode;
  final String? routineId;
  final String? occurrenceId;
  final String? prescriptionId;
  final MvSessionMode sessionMode;
  final MvSessionStatus status;
  final int startedAt;
  final int? endedAt;
  final int pausedMs;
  final String? targetJson;
  final String? liveJson;
  final String? workoutLogId;
  final MvSessionFeeling? overallFeeling;
  final String? note;
  final int createdAt;
  final int updatedAt;

  const MvSession({
    required this.id,
    required this.kindCode,
    this.routineId,
    this.occurrenceId,
    this.prescriptionId,
    this.sessionMode = MvSessionMode.guided,
    this.status = MvSessionStatus.active,
    required this.startedAt,
    this.endedAt,
    this.pausedMs = 0,
    this.targetJson,
    this.liveJson,
    this.workoutLogId,
    this.overallFeeling,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == MvSessionStatus.active;
  bool get isPaused => status == MvSessionStatus.paused;
  bool get isFinished => status == MvSessionStatus.completed || status == MvSessionStatus.partial;

  int get elapsedMs {
    final now = endedAt ?? DateTime.now().millisecondsSinceEpoch;
    final gross = now - startedAt;
    final net = gross - pausedMs;
    return net < 0 ? 0 : net;
  }

  int get elapsedMinutes => (elapsedMs / 60000).round();

  MvSession copyWith({
    String? id,
    String? kindCode,
    String? routineId,
    String? occurrenceId,
    String? prescriptionId,
    MvSessionMode? sessionMode,
    MvSessionStatus? status,
    int? startedAt,
    int? endedAt,
    int? pausedMs,
    String? targetJson,
    String? liveJson,
    String? workoutLogId,
    MvSessionFeeling? overallFeeling,
    String? note,
    int? createdAt,
    int? updatedAt,
  }) {
    return MvSession(
      id: id ?? this.id,
      kindCode: kindCode ?? this.kindCode,
      routineId: routineId ?? this.routineId,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      sessionMode: sessionMode ?? this.sessionMode,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      pausedMs: pausedMs ?? this.pausedMs,
      targetJson: targetJson ?? this.targetJson,
      liveJson: liveJson ?? this.liveJson,
      workoutLogId: workoutLogId ?? this.workoutLogId,
      overallFeeling: overallFeeling ?? this.overallFeeling,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kindCode': kindCode,
      'routineId': routineId,
      'occurrenceId': occurrenceId,
      'prescriptionId': prescriptionId,
      'sessionMode': sessionMode.code,
      'status': status.code,
      'startedAt': startedAt,
      'endedAt': endedAt,
      'pausedMs': pausedMs,
      'targetJson': targetJson,
      'liveJson': liveJson,
      'workoutLogId': workoutLogId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory MvSession.fromMap(Map<String, dynamic> map) {
    return MvSession(
      id: map['id'] as String,
      kindCode: (map['kindCode'] as String?) ?? 'bodyweight',
      routineId: map['routineId'] as String?,
      occurrenceId: map['occurrenceId'] as String?,
      prescriptionId: map['prescriptionId'] as String?,
      sessionMode: MvSessionMode.fromCode(map['sessionMode'] as String?),
      status: MvSessionStatus.fromCode(map['status'] as String?),
      startedAt: (map['startedAt'] as num).toInt(),
      endedAt: (map['endedAt'] as num?)?.toInt(),
      pausedMs: (map['pausedMs'] as num?)?.toInt() ?? 0,
      targetJson: map['targetJson'] as String?,
      liveJson: map['liveJson'] as String?,
      workoutLogId: map['workoutLogId'] as String?,
      createdAt: (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: (map['updatedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Represents an event during session lifecycle for resilient crash recovery.
class MvSessionEvent {
  final String id;
  final String sessionId;
  final String type;
  final int at;
  final String? dataJson;

  const MvSessionEvent({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.at,
    this.dataJson,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'type': type,
      'at': at,
      'dataJson': dataJson,
    };
  }

  factory MvSessionEvent.fromMap(Map<String, dynamic> map) {
    return MvSessionEvent(
      id: map['id'] as String,
      sessionId: map['sessionId'] as String,
      type: map['type'] as String,
      at: (map['at'] as num).toInt(),
      dataJson: map['dataJson'] as String?,
    );
  }
}
