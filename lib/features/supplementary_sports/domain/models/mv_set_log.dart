/// Single Source of Truth for Workout Set Execution (`ss_session_set_log`).
class MvSetLog {
  final String id;
  final String sessionId;
  final String exerciseId;
  final int setNumber;
  final double? weight;
  final int? reps;
  final int? rir;
  final int? durationSeconds;
  final bool isCompleted;
  final int loggedAt;

  const MvSetLog({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.setNumber,
    this.weight,
    this.reps,
    this.rir,
    this.durationSeconds,
    this.isCompleted = true,
    required this.loggedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'exerciseId': exerciseId,
      'setNumber': setNumber,
      'weight': weight,
      'reps': reps,
      'rir': rir,
      'durationSeconds': durationSeconds,
      'isCompleted': isCompleted ? 1 : 0,
      'loggedAt': loggedAt,
    };
  }

  factory MvSetLog.fromMap(Map<String, dynamic> map) {
    return MvSetLog(
      id: map['id'] as String,
      sessionId: map['sessionId'] as String,
      exerciseId: map['exerciseId'] as String,
      setNumber: (map['setNumber'] as num).toInt(),
      weight: (map['weight'] as num?)?.toDouble(),
      reps: (map['reps'] as num?)?.toInt(),
      rir: (map['rir'] as num?)?.toInt(),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt(),
      isCompleted: (map['isCompleted'] as num?)?.toInt() == 1,
      loggedAt: (map['loggedAt'] as num).toInt(),
    );
  }
}
