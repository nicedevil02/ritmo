import '../models/models.dart';

/// Body Map Muscle Workload distribution.
class MvBodyMapDistribution {
  final Map<String, int> muscleSessionCounts; // MuscleGroup code -> count
  final String? neglectedMuscleGroupCode;
  final String? suggestedActionFa;

  const MvBodyMapDistribution({
    required this.muscleSessionCounts,
    this.neglectedMuscleGroupCode,
    this.suggestedActionFa,
  });
}

/// 7.9 InsightEngine: Generates progress insights, muscle balance maps, and active streaks.
class InsightEngine {
  const InsightEngine();

  /// Calculates muscle group workloads and highlights imbalances.
  MvDecision<MvBodyMapDistribution> calculateMuscleDistribution({
    required List<MvSlot> completedSlots,
  }) {
    final counts = <String, int>{};
    for (final mg in MvMuscleGroup.all) {
      counts[mg.code] = 0;
    }

    for (final slot in completedSlots) {
      for (final code in slot.focusCodes) {
        final upper = code.toUpperCase();
        counts[upper] = (counts[upper] ?? 0) + 1;
      }
    }

    // Check for neglected major muscle group
    String? neglected;
    String? actionFa;

    if (completedSlots.isNotEmpty) {
      if ((counts['BACK'] ?? 0) == 0 && (counts['CHEST'] ?? 0) > 1) {
        neglected = 'BACK';
        actionFa = 'عضلات پشت این هفته تمرین نداشته — یک جلسهٔ ۱۵ دقیقه‌ای تنظیم کنم؟';
      } else if ((counts['QUADS_GLUTES'] ?? 0) == 0 && (counts['UPPER'] ?? 0) > 1) {
        neglected = 'QUADS_GLUTES';
        actionFa = 'پایین‌تنه این هفته کمتر کار کرده — یک جلسهٔ سبک بسازم؟';
      }
    }

    final distribution = MvBodyMapDistribution(
      muscleSessionCounts: counts,
      neglectedMuscleGroupCode: neglected,
      suggestedActionFa: actionFa,
    );

    final reasonFa = actionFa ?? 'توزیع فشار عضلانی در طول هفته متعادل است.';

    return MvDecision<MvBodyMapDistribution>(
      value: distribution,
      reasonFa: reasonFa,
      sources: const ['session_logs'],
      confidence: completedSlots.length >= 2 ? 0.95 : 0.5,
      hasEnoughData: completedSlots.isNotEmpty,
    );
  }

  /// Calculates continuous active weeks.
  int calculateContinuousActiveWeeks(List<int> weeklyActiveDayCounts, {int minimumDaysThreshold = 2}) {
    int streak = 0;
    for (final days in weeklyActiveDayCounts.reversed) {
      if (days >= minimumDaysThreshold) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}
