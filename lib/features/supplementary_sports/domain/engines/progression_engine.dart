import '../models/models.dart';

/// Target progression output for an exercise.
class MvExerciseProgressionTarget {
  final int targetReps;
  final double? targetWeight;
  final int targetSets;

  const MvExerciseProgressionTarget({
    required this.targetReps,
    this.targetWeight,
    this.targetSets = 3,
  });
}

/// 7.6 ProgressionEngine: Calculates target progression (sets/reps/weight) and evaluates personal records.
class ProgressionEngine {
  const ProgressionEngine();

  /// Calculates the next target sets/reps/weight for an exercise based on recent logs and feeling.
  MvDecision<MvExerciseProgressionTarget> calculateNextTarget({
    required MvExercise exercise,
    required List<MvSetLog> recentSetLogs,
    MvSessionFeeling? lastFeeling,
    bool isDeload = false,
  }) {
    if (isDeload) {
      final baseReps = (exercise.defaultReps * 0.8).round().clamp(6, 30);
      return MvDecision<MvExerciseProgressionTarget>(
        value: MvExerciseProgressionTarget(targetReps: baseReps, targetSets: 2),
        reasonFa: 'هفتهٔ سبک: حجم ست‌ها و تکرارها برای بازیابی کاهش یافت.',
        sources: const ['deload_policy'],
        confidence: 1.0,
        hasEnoughData: true,
      );
    }

    if (recentSetLogs.isEmpty) {
      return MvDecision<MvExerciseProgressionTarget>(
        value: MvExerciseProgressionTarget(
          targetReps: exercise.defaultReps > 0 ? exercise.defaultReps : 10,
          targetSets: 3,
        ),
        reasonFa: 'هدف استاندارد بر اساس سطح آمادگی پایه تعیین شد.',
        sources: const ['exercise_defaults'],
        confidence: 0.8,
        hasEnoughData: false,
      );
    }

    // Analyze previous performance
    final maxRepsLogged = recentSetLogs
        .map((s) => s.reps ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final lastWeight = recentSetLogs
        .map((s) => s.weight ?? 0.0)
        .fold<double>(0.0, (a, b) => a > b ? a : b);

    int nextReps = maxRepsLogged > 0 ? maxRepsLogged : exercise.defaultReps;
    double? nextWeight = lastWeight > 0 ? lastWeight : null;
    String reason = 'حفظ دستاورد و تکرار روند قبلی.';

    if (lastFeeling == MvSessionFeeling.easy) {
      if (nextWeight != null && nextWeight > 0) {
        nextWeight += 2.0;
        reason = 'به دلیل راحتی جلسه قبل، وزنه ۲ کیلوگرم افزایش یافت.';
      } else {
        nextReps += 2;
        reason = 'به دلیل راحتی جلسه قبل، ۲ تکرار به هدف اضافه شد.';
      }
    } else if (lastFeeling == MvSessionFeeling.hard) {
      reason =
          'به دلیل چالش جلسه قبل، هدف فعلی بدون افزایش حفظ شد تا بدنت تثبیت شود.';
    }

    return MvDecision<MvExerciseProgressionTarget>(
      value: MvExerciseProgressionTarget(
        targetReps: nextReps,
        targetWeight: nextWeight,
        targetSets: 3,
      ),
      reasonFa: reason,
      sources: const ['history_logs', 'session_feeling'],
      confidence: 0.95,
      hasEnoughData: true,
    );
  }

  /// Evaluates if a set log qualifies as a new personal record.
  MvPersonalRecord? evaluateNewRecord({
    required MvSetLog setLog,
    required MvPersonalRecord? currentBest,
  }) {
    final reps = setLog.reps ?? 0;
    if (reps <= 0) return null;

    final currentVal = currentBest?.value ?? 0.0;
    if (reps.toDouble() > currentVal) {
      return MvPersonalRecord(
        id: 'pr_${setLog.exerciseId}_reps',
        kind: 'EXERCISE:${setLog.exerciseId}',
        prType: MvPrType.maxReps,
        value: reps.toDouble(),
        logId: setLog.sessionId,
        achievedAt: setLog.loggedAt,
      );
    }
    return null;
  }

  /// Evaluates if a completed session sets any new kind-specific personal records (S5-T3).
  List<MvPersonalRecord> evaluateSessionRecords({
    required MvSession session,
    required List<MvPersonalRecord> existingPrsForKind,
  }) {
    final newPrs = <MvPersonalRecord>[];
    final kindCode = session.kindCode.toUpperCase();
    final achievedAt = session.endedAt ?? session.startedAt;
    final sessionId = session.id;

    MvPersonalRecord? findPr(MvPrType type) {
      for (final p in existingPrsForKind) {
        if (p.prType == type && p.kind == kindCode) {
          return p;
        }
      }
      return null;
    }

    // 1. DURATION: Longest session duration (in minutes)
    final durationMin = session.elapsedMinutes;
    if (durationMin > 0) {
      final bestDuration = findPr(MvPrType.longestDuration);
      if (bestDuration == null || durationMin > bestDuration.value) {
        newPrs.add(
          MvPersonalRecord(
            id: 'pr_${kindCode}_duration',
            kind: kindCode,
            prType: MvPrType.longestDuration,
            value: durationMin.toDouble(),
            logId: sessionId,
            achievedAt: achievedAt,
          ),
        );
      }
    }

    // 2. DISTANCE: Longest distance (in meters)
    final distanceM = session.distanceM ?? 0.0;
    if (distanceM > 0) {
      final bestDistance = findPr(MvPrType.longestDistance);
      if (bestDistance == null || distanceM > bestDistance.value) {
        newPrs.add(
          MvPersonalRecord(
            id: 'pr_${kindCode}_distance',
            kind: kindCode,
            prType: MvPrType.longestDistance,
            value: distanceM,
            logId: sessionId,
            achievedAt: achievedAt,
          ),
        );
      }

      // DISTANCE: Best tempo/pace on 5km+ runs/rides (pace in sec/km, lower is better)
      if (distanceM >= 5000.0) {
        final pace = session.paceSecPerKm;
        if (pace != null && pace > 0) {
          final bestPace = findPr(MvPrType.bestPace5k);
          if (bestPace == null || pace < bestPace.value) {
            newPrs.add(
              MvPersonalRecord(
                id: 'pr_${kindCode}_pace5k',
                kind: kindCode,
                prType: MvPrType.bestPace5k,
                value: pace,
                logId: sessionId,
                achievedAt: achievedAt,
              ),
            );
          }
        }
      }
    }

    // 3. ELEVATION: Max elevation gain (in meters)
    final elevationGainM = session.elevationGainM ?? 0.0;
    if (elevationGainM > 0) {
      final bestElev = findPr(MvPrType.maxElevation);
      if (bestElev == null || elevationGainM > bestElev.value) {
        newPrs.add(
          MvPersonalRecord(
            id: 'pr_${kindCode}_elevation',
            kind: kindCode,
            prType: MvPrType.maxElevation,
            value: elevationGainM,
            logId: sessionId,
            achievedAt: achievedAt,
          ),
        );
      }
    }

    // ELEVATION: Max pack weight (in kg)
    final packWeightKg = session.packWeightKg ?? 0.0;
    if (packWeightKg > 0) {
      final bestPack = findPr(MvPrType.maxPackWeight);
      if (bestPack == null || packWeightKg > bestPack.value) {
        newPrs.add(
          MvPersonalRecord(
            id: 'pr_${kindCode}_pack_weight',
            kind: kindCode,
            prType: MvPrType.maxPackWeight,
            value: packWeightKg,
            logId: sessionId,
            achievedAt: achievedAt,
          ),
        );
      }
    }

    // 4. LAPS: Max laps
    final laps = session.laps ?? 0;
    if (laps > 0) {
      final bestLaps = findPr(MvPrType.maxLaps);
      if (bestLaps == null || laps > bestLaps.value) {
        newPrs.add(
          MvPersonalRecord(
            id: 'pr_${kindCode}_laps',
            kind: kindCode,
            prType: MvPrType.maxLaps,
            value: laps.toDouble(),
            logId: sessionId,
            achievedAt: achievedAt,
          ),
        );
      }
    }

    return newPrs;
  }
}
