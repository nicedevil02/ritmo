import 'dart:convert';
import 'package:flutter/foundation.dart';

enum MovementSessionStatus {
  active('ACTIVE'),
  paused('PAUSED'),
  completed('COMPLETED'),
  abandoned('ABANDONED');

  const MovementSessionStatus(this.code);
  final String code;

  static MovementSessionStatus fromCode(String code) {
    final clean = code.toUpperCase();
    return values.firstWhere(
      (v) => v.code == clean,
      orElse: () => MovementSessionStatus.abandoned,
    );
  }
}

enum SessionEventType {
  start,
  pause,
  resume,
  lap,
  split,
  sample,
  note,
  finish,
  abandon,
}

class MovementSession {
  const MovementSession({
    required this.id,
    required this.kindCode,
    required this.sessionMode,
    required this.status,
    required this.startedAt,
    this.routineId,
    this.occurrenceId,
    this.prescriptionId,
    this.endedAt,
    this.pausedMs = 0,
    this.targetJson,
    this.liveJson,
    this.workoutLogId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String kindCode;
  final String sessionMode;
  final MovementSessionStatus status;
  final int startedAt;
  final int? endedAt;
  final int pausedMs;
  final String? routineId;
  final String? occurrenceId;
  final String? prescriptionId;
  final String? targetJson;
  final String? liveJson;
  final String? workoutLogId;
  final int createdAt;
  final int updatedAt;

  /// زمان سپری‌شدهٔ واقعی — همیشه از ساعت دیواری، نه جمع تیک‌ها.
  int get elapsedMs {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (status == MovementSessionStatus.paused && liveJson != null) {
      try {
        final Map<String, dynamic> live = Map<String, dynamic>.from(
          jsonDecode(liveJson!) as Map,
        );
        final pauseStartedAt = live['pauseStartedAt'] as int?;
        if (pauseStartedAt != null) {
          return pauseStartedAt - startedAt - pausedMs;
        }
      } catch (e) {
        debugPrint('[ss] movement_session.dart: $e');
      }
    }
    final baseEnd = endedAt ?? now;
    return baseEnd - startedAt - pausedMs;
  }

  bool get isLive =>
      status == MovementSessionStatus.active ||
      status == MovementSessionStatus.paused;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kindCode': kindCode,
      'sessionMode': sessionMode,
      'status': status.code,
      'startedAt': startedAt,
      'endedAt': endedAt,
      'pausedMs': pausedMs,
      'routineId': routineId,
      'occurrenceId': occurrenceId,
      'prescriptionId': prescriptionId,
      'targetJson': targetJson,
      'liveJson': liveJson,
      'workoutLogId': workoutLogId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory MovementSession.fromMap(Map<String, dynamic> map) {
    return MovementSession(
      id: map['id'] as String,
      kindCode: map['kindCode'] as String,
      sessionMode: map['sessionMode'] as String,
      status: MovementSessionStatus.fromCode(
        map['status'] as String? ?? 'ABANDONED',
      ),
      startedAt: map['startedAt'] as int,
      endedAt: map['endedAt'] as int?,
      pausedMs: map['pausedMs'] as int? ?? 0,
      routineId: map['routineId'] as String?,
      occurrenceId: map['occurrenceId'] as String?,
      prescriptionId: map['prescriptionId'] as String?,
      targetJson: map['targetJson'] as String?,
      liveJson: map['liveJson'] as String?,
      workoutLogId: map['workoutLogId'] as String?,
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
    );
  }
}
