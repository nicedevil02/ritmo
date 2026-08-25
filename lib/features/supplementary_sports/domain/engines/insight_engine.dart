import '../models/models.dart';

/// Body Map Muscle Workload distribution.
class MvBodyMapDistribution {
  final Map<String, int> muscleSessionCounts; // MuscleGroup code -> count / sets
  final Map<String, double> musclePercentages; // MuscleGroup code -> percentage (0..100)
  final String? neglectedMuscleGroupCode;
  final double? neglectedPercentOfVolume;
  final String? suggestedActionFa;
  final int totalSetsCount;

  const MvBodyMapDistribution({
    required this.muscleSessionCounts,
    this.musclePercentages = const {},
    this.neglectedMuscleGroupCode,
    this.neglectedPercentOfVolume,
    this.suggestedActionFa,
    this.totalSetsCount = 0,
  });
}

/// 7.9 InsightEngine: Generates progress insights, muscle balance maps, and active streaks.
class InsightEngine {
  const InsightEngine();

  /// Calculates muscle group workloads and highlights imbalances honestly (S0-T5).
  MvDecision<MvBodyMapDistribution?> calculateMuscleDistribution({
    List<MvSlot> completedSlots = const [],
    List<MvSetLog> completedSetLogs = const [],
    Map<String, List<String>> exerciseMuscleMap = const {},
    int? completedSessionsCount,
  }) {
    final sessionCount = completedSessionsCount ?? completedSlots.length;
    final bool hasEnoughData = sessionCount >= 3;

    final counts = <String, int>{};
    for (final mg in MvMuscleGroup.all) {
      counts[mg.code] = 0;
    }

    int totalUnits = 0;

    if (completedSetLogs.isNotEmpty) {
      for (final setLog in completedSetLogs) {
        final muscles = exerciseMuscleMap[setLog.exerciseId] ?? const [];
        if (muscles.isEmpty) {
          counts['FULL_BODY'] = (counts['FULL_BODY'] ?? 0) + 1;
          totalUnits++;
        } else {
          for (final m in muscles) {
            final upper = m.toUpperCase();
            counts[upper] = (counts[upper] ?? 0) + 1;
            totalUnits++;
          }
        }
      }
    } else if (completedSlots.isNotEmpty) {
      for (final slot in completedSlots) {
        for (final code in slot.focusCodes) {
          final upper = code.toUpperCase();
          counts[upper] = (counts[upper] ?? 0) + 1;
          totalUnits++;
        }
      }
    }

    if (totalUnits == 0) {
      return const MvDecision<MvBodyMapDistribution?>(
        value: null,
        reasonFa: 'هنوز دادهٔ کافی برای تفکیک عضلات ثبت نشده است.',
        sources: ['session_logs'],
        confidence: 0.0,
        hasEnoughData: false,
      );
    }

    final percentages = <String, double>{};
    for (final entry in counts.entries) {
      if (entry.value > 0) {
        percentages[entry.key] = (entry.value / totalUnits) * 100.0;
      }
    }

    // Check for neglected major muscle group
    String? neglected;
    double? neglectedPercent;
    String? actionFa;

    final chestPercent = percentages['CHEST'] ?? 0.0;
    final backPercent = percentages['BACK'] ?? 0.0;
    final legsPercent =
        (percentages['QUADS_GLUTES'] ?? 0.0) + (percentages['LEGS'] ?? 0.0);

    if (chestPercent > 30.0 && backPercent < 10.0) {
      neglected = 'BACK';
      neglectedPercent = backPercent;
      actionFa =
          'عضلات پشت این هفته تمرین نداشته — یک جلسهٔ ۱۵ دقیقه‌ای تنظیم کنم؟';
    } else if (legsPercent < 15.0 && totalUnits >= 6) {
      neglected = 'QUADS_GLUTES';
      neglectedPercent = legsPercent;
      actionFa = 'پایین‌تنه این هفته کمتر کار کرده — یک جلسهٔ سبک بسازم؟';
    }

    final distribution = MvBodyMapDistribution(
      muscleSessionCounts: counts,
      musclePercentages: percentages,
      neglectedMuscleGroupCode: neglected,
      neglectedPercentOfVolume: neglectedPercent,
      suggestedActionFa: actionFa,
      totalSetsCount: totalUnits,
    );

    final reasonFa = actionFa ?? 'توزیع فشار عضلانی در طول هفته متعادل است.';

    return MvDecision<MvBodyMapDistribution?>(
      value: distribution,
      reasonFa: reasonFa,
      sources: const ['session_logs', 'set_logs'],
      confidence: hasEnoughData ? 0.95 : 0.4,
      hasEnoughData: hasEnoughData,
    );
  }

  /// Calculates continuous active weeks.
  int calculateContinuousActiveWeeks(
    List<int> weeklyActiveDayCounts, {
    int minimumDaysThreshold = 2,
  }) {
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
