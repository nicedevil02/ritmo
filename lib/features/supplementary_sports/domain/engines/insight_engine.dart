import '../models/models.dart';

/// Body Map Muscle Workload distribution.
class MvBodyMapDistribution {
  final Map<String, int>
  muscleSessionCounts; // MuscleGroup code -> count / sets
  final Map<String, double>
  musclePercentages; // MuscleGroup code -> percentage (0..100)
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

  /// Generates exactly the 5 deterministic insights defined in S5-T6 table.
  /// If a condition is not met, the insight is omitted (no generic fallback sentences).
  List<MvInsight> generateInsights({
    required List<MvSession> completedSessions,
    List<MvCommitment> activeCommitments = const [],
    int commitmentWeeks = 0,
    int plannedAnchorSessions = 0,
    int completedAnchorSessions = 0,
    List<MvRoute> routes = const [],
    Map<String, MvMovementKind> kindsMap = const {},
    DateTime? referenceDate,
  }) {
    final insights = <MvInsight>[];
    final now = referenceDate ?? DateTime.now();

    // 1. mv_insight_best_day: >=8 completed sessions; day completion rate >=20% above mean
    if (completedSessions.length >= 8) {
      final dayCounts = <int, int>{for (int d = 1; d <= 7; d++) d: 0};
      for (final s in completedSessions) {
        final d = DateTime.fromMillisecondsSinceEpoch(s.startedAt).weekday;
        dayCounts[d] = (dayCounts[d] ?? 0) + 1;
      }
      final total = completedSessions.length;
      final avg = total / 7.0;

      int bestDay = 1;
      int maxCount = 0;
      dayCounts.forEach((day, count) {
        if (count > maxCount) {
          maxCount = count;
          bestDay = day;
        }
      });

      if (avg > 0 && ((maxCount - avg) / avg) >= 0.20) {
        final dayNames = {
          DateTime.saturday: 'شنبه',
          DateTime.sunday: 'یک‌شنبه',
          DateTime.monday: 'دوشنبه',
          DateTime.tuesday: 'سه‌شنبه',
          DateTime.wednesday: 'چهارشنبه',
          DateTime.thursday: 'پنج‌شنبه',
          DateTime.friday: 'جمعه',
        };
        final dayName = dayNames[bestDay] ?? 'این روز';
        insights.add(
          MvInsight(
            key: 'mv_insight_best_day',
            titleFa: 'روز طلایی تمرین',
            descriptionFa:
                'به نظر می‌رسد روزهای $dayName با بیشترین نرخ تکمیل، مناسب‌ترین زمان برای تمرین شماست.',
            params: {'bestDay': bestDay, 'dayName': dayName, 'count': maxCount},
          ),
        );
      }
    }

    // 2. mv_insight_anchor_adherence: >=4 weeks active commitment; anchor attendance rate
    if (activeCommitments.isNotEmpty &&
        commitmentWeeks >= 4 &&
        plannedAnchorSessions > 0) {
      final rate = ((completedAnchorSessions / plannedAnchorSessions) * 100)
          .round()
          .clamp(0, 100);
      insights.add(
        MvInsight(
          key: 'mv_insight_anchor_adherence',
          titleFa: 'پایبندی به لنگرها',
          descriptionFa:
              'در ۴ هفتهٔ گذشته، نرخ حضور شما در جلسات ثابت لنگر $rate٪ ثبت شده است.',
          params: {'adherenceRate': rate, 'weeks': commitmentWeeks},
        ),
      );
    }

    // 3. mv_insight_effort_drift: >=10 sessions with effortSource == 'user'; RPE change between 2 months
    final userEffortSessions = completedSessions
        .where((s) => s.effortSource == 'user' && s.rpe1To10 != null)
        .toList();
    if (userEffortSessions.length >= 10) {
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final sixtyDaysAgo = now.subtract(const Duration(days: 60));

      final recent = userEffortSessions.where((s) {
        final dt = DateTime.fromMillisecondsSinceEpoch(s.startedAt);
        return dt.isAfter(thirtyDaysAgo);
      }).toList();

      final previous = userEffortSessions.where((s) {
        final dt = DateTime.fromMillisecondsSinceEpoch(s.startedAt);
        return dt.isAfter(sixtyDaysAgo) && dt.isBefore(thirtyDaysAgo);
      }).toList();

      if (recent.length >= 3 && previous.length >= 3) {
        final recentAvg =
            recent.map((s) => s.rpe1To10!).reduce((a, b) => a + b) /
            recent.length;
        final prevAvg =
            previous.map((s) => s.rpe1To10!).reduce((a, b) => a + b) /
            previous.length;
        final delta = recentAvg - prevAvg;

        if (delta.abs() >= 0.5) {
          final trend = delta > 0 ? 'افزایش' : 'کاهش';
          insights.add(
            MvInsight(
              key: 'mv_insight_effort_drift',
              titleFa: 'روند ادراک فشار',
              descriptionFa:
                  'به نظر می‌رسد میانگین فشار تمرینی انتخابی شما در ماه جاری نسبت به ماه قبل $trend یافته است.',
              params: {
                'recentAvg': recentAvg,
                'prevAvg': prevAvg,
                'delta': delta,
              },
            ),
          );
        }
      }
    }

    // 4. mv_insight_kind_mix: >=3 distinct kinds in current month; dominant share
    final startOfMonth = DateTime(now.year, now.month, 1);
    final monthSessions = completedSessions.where((s) {
      final dt = DateTime.fromMillisecondsSinceEpoch(s.startedAt);
      return dt.isAfter(startOfMonth) || dt.isAtSameMomentAs(startOfMonth);
    }).toList();

    final distinctKinds = monthSessions
        .map((s) => s.kindCode.toUpperCase())
        .toSet();
    if (distinctKinds.length >= 3) {
      final kindCounts = <String, int>{};
      for (final s in monthSessions) {
        final k = s.kindCode.toUpperCase();
        kindCounts[k] = (kindCounts[k] ?? 0) + 1;
      }
      final topCode = kindCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      final topKind = kindsMap[topCode];
      final topTitle = topKind?.titleFa ?? topCode;

      insights.add(
        MvInsight(
          key: 'mv_insight_kind_mix',
          titleFa: 'تنوع ورزشی ماهانه',
          descriptionFa:
              'در ماه جاری ۳ نوع ورزش یا بیشتر انجام داده‌اید و سهم غالب با $topTitle به نظر می‌رسد.',
          params: {'distinctCount': distinctKinds.length, 'topKind': topTitle},
        ),
      );
    }

    // 5. mv_insight_route_progress: route with >=3 completions
    for (final r in routes) {
      if (r.timesCompleted >= 3) {
        insights.add(
          MvInsight(
            key: 'mv_insight_route_progress',
            titleFa: 'پیشرفت در مسیر تکراری',
            descriptionFa:
                'مسیر «${r.titleFa}» را ${r.timesCompleted} بار پیموده‌اید و بهترین زمان شما ${r.bestDurationMin ?? 0} دقیقه ثبت شده است.',
            params: {
              'routeId': r.id,
              'titleFa': r.titleFa,
              'timesCompleted': r.timesCompleted,
            },
          ),
        );
        break; // Show top/first qualifying route
      }
    }

    return insights;
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

/// Immutable Model for Progress Insights (S5-T6).
class MvInsight {
  final String key;
  final String titleFa;
  final String descriptionFa;
  final Map<String, dynamic> params;

  const MvInsight({
    required this.key,
    required this.titleFa,
    required this.descriptionFa,
    this.params = const {},
  });
}
