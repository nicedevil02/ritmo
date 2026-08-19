import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';

/// وضعیت جلسهٔ زنده
enum MovementLiveSessionStatus {
  preparing,
  active,
  paused,
  recovering,
  finishing,
  completed,
  abandoned,
  errorRecoverable;

  static MovementLiveSessionStatus fromString(String val) {
    return MovementLiveSessionStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => MovementLiveSessionStatus.active,
    );
  }
}

/// مدل جلسهٔ زنده
class MovementLiveSession {
  const MovementLiveSession({
    required this.id,
    this.occurrenceId,
    required this.activityKindId,
    this.activityKind,
    required this.mode,
    required this.status,
    this.startedAt,
    this.accumulatedPauseMs = 0,
    this.targetSnapshotJson,
    this.finishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? occurrenceId;
  final String activityKindId;
  final MovementActivityKind? activityKind;
  final String
  mode; // standard, interval, strength, quick, time, distance, lap, count, free
  final MovementLiveSessionStatus status;
  final DateTime? startedAt;
  final int accumulatedPauseMs;
  final String? targetSnapshotJson;
  final DateTime? finishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActiveOrPaused =>
      status == MovementLiveSessionStatus.active ||
      status == MovementLiveSessionStatus.paused;

  int get elapsedSeconds {
    if (startedAt == null) return 0;
    final now = finishedAt ?? DateTime.now();
    final totalMs =
        now.difference(startedAt!).inMilliseconds - accumulatedPauseMs;
    return totalMs > 0 ? (totalMs / 1000).floor() : 0;
  }

  MovementLiveSession copyWith({
    String? id,
    String? occurrenceId,
    String? activityKindId,
    MovementActivityKind? activityKind,
    String? mode,
    MovementLiveSessionStatus? status,
    DateTime? startedAt,
    int? accumulatedPauseMs,
    String? targetSnapshotJson,
    DateTime? finishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MovementLiveSession(
      id: id ?? this.id,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      activityKindId: activityKindId ?? this.activityKindId,
      activityKind: activityKind ?? this.activityKind,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      accumulatedPauseMs: accumulatedPauseMs ?? this.accumulatedPauseMs,
      targetSnapshotJson: targetSnapshotJson ?? this.targetSnapshotJson,
      finishedAt: finishedAt ?? this.finishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MovementLiveSession.fromMap(
    Map<String, dynamic> map, {
    MovementActivityKind? activityKind,
  }) {
    return MovementLiveSession(
      id: map['id'] as String,
      occurrenceId: map['occurrenceId'] as String?,
      activityKindId: map['activityKindId'] as String,
      activityKind: activityKind,
      mode: map['mode'] as String? ?? 'time',
      status: MovementLiveSessionStatus.fromString(
        map['status'] as String? ?? 'active',
      ),
      startedAt: map['startedAt'] != null
          ? DateTime.tryParse(map['startedAt'].toString())
          : null,
      accumulatedPauseMs: map['accumulatedPauseMs'] as int? ?? 0,
      targetSnapshotJson: map['targetSnapshotJson'] as String?,
      finishedAt: map['finishedAt'] != null
          ? DateTime.tryParse(map['finishedAt'].toString())
          : null,
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
      'occurrenceId': occurrenceId,
      'activityKindId': activityKindId,
      'mode': mode,
      'status': status.name,
      'startedAt': startedAt?.toIso8601String(),
      'accumulatedPauseMs': accumulatedPauseMs,
      'targetSnapshotJson': targetSnapshotJson,
      'finishedAt': finishedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
