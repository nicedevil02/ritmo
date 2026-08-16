/// مدل ثبت ست‌های تمرینی در جلسهٔ قدرتی
class MovementSetLog {
  const MovementSetLog({
    required this.id,
    this.sessionId,
    this.occurrenceId,
    required this.exerciseId,
    required this.setIndex,
    this.weightKg,
    this.reps,
    this.rir,
    this.completed = false,
    this.skipped = false,
    required this.at,
  });

  final String id;
  final String? sessionId;
  final String? occurrenceId;
  final String exerciseId;
  final int setIndex;
  final double? weightKg;
  final int? reps;
  final double? rir; // Reps In Reserve (optional)
  final bool completed;
  final bool skipped;
  final DateTime at;

  MovementSetLog copyWith({
    String? id,
    String? sessionId,
    String? occurrenceId,
    String? exerciseId,
    int? setIndex,
    double? weightKg,
    int? reps,
    double? rir,
    bool? completed,
    bool? skipped,
    DateTime? at,
  }) {
    return MovementSetLog(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      exerciseId: exerciseId ?? this.exerciseId,
      setIndex: setIndex ?? this.setIndex,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      rir: rir ?? this.rir,
      completed: completed ?? this.completed,
      skipped: skipped ?? this.skipped,
      at: at ?? this.at,
    );
  }

  factory MovementSetLog.fromMap(Map<String, dynamic> map) {
    return MovementSetLog(
      id: map['id'] as String,
      sessionId: map['sessionId'] as String?,
      occurrenceId: map['occurrenceId'] as String?,
      exerciseId: map['exerciseId'] as String,
      setIndex: (map['setIndex'] as int?) ?? 1,
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      reps: map['reps'] as int?,
      rir: (map['rir'] as num?)?.toDouble(),
      completed: (map['completed'] as int? ?? 0) == 1,
      skipped: (map['skipped'] as int? ?? 0) == 1,
      at: DateTime.tryParse(map['at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'occurrenceId': occurrenceId,
      'exerciseId': exerciseId,
      'setIndex': setIndex,
      'weightKg': weightKg,
      'reps': reps,
      'rir': rir,
      'completed': completed ? 1 : 0,
      'skipped': skipped ? 1 : 0,
      'at': at.toUtc().toIso8601String(),
    };
  }
}
