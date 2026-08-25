import '../models/models.dart';

/// Weekly Activity Progress Summary based on WHO Physical Activity Guidelines.
class MvWeeklyBudgetProgress {
  final int moderateEquivalentMinutes;
  final double rawMetMinutes;
  final int strengthDays;
  final int targetMin; // 150
  final int targetOptimal; // 300
  final int strengthDaysTarget; // 2
  final double? forecastedModerateMinutes;
  final bool hasEnoughDataForForecast;
  final int currentActiveDays;
  final int targetActiveDays;

  const MvWeeklyBudgetProgress({
    required this.moderateEquivalentMinutes,
    required this.rawMetMinutes,
    required this.strengthDays,
    this.targetMin = 150,
    this.targetOptimal = 300,
    this.strengthDaysTarget = 2,
    this.forecastedModerateMinutes,
    this.hasEnoughDataForForecast = false,
    int? currentActiveDays,
    int? targetActiveDays,
  })  : currentActiveDays = currentActiveDays ?? strengthDays,
        targetActiveDays = targetActiveDays ?? strengthDaysTarget;

  double get targetMetMinutes => targetMin.toDouble();
  double get currentMetMinutes => rawMetMinutes;
  double? get forecastedMetMinutes => forecastedModerateMinutes;

  double get percentage => targetMin > 0
      ? (moderateEquivalentMinutes / targetMin).clamp(0.0, 1.5)
      : 0.0;
}

/// 7.8 BudgetEngine: Evaluates weekly active minutes (WHO moderate-equivalent & MET-min) budget and progress.
class BudgetEngine {
  const BudgetEngine();

  /// Calculates weekly target and accumulated WHO progress.
  MvDecision<MvWeeklyBudgetProgress> calculateWeeklyProgress({
    MvUserProfile? profile,
    required List<MvSession> weekCompletedSessions,
    required int currentDayOfWeekSat0, // 0=Sat .. 6=Fri
    Map<String, MvMovementKind> kindsByCode = const {},
  }) {
    int totalModerateEquivalent = 0;
    double totalRawMet = 0.0;
    final activeDaysSet = <String>{};
    final strengthDaysSet = <String>{};

    for (final sess in weekCompletedSessions) {
      if (!sess.isFinished) continue;
      final minutes = sess.elapsedMinutes;
      if (minutes <= 0) continue;

      final kind = kindsByCode[sess.kindCode.toUpperCase()];
      final baseMet = kind?.baseMet ?? 5.0;

      // Moderate Equivalent minutes per §4.2:
      // met < 3.0 -> 0 (light, not counted)
      // met < 6.0 -> minutes (moderate)
      // else      -> minutes * 2 (vigorous)
      int sessionModEquiv = 0;
      if (baseMet < 3.0) {
        sessionModEquiv = 0;
      } else if (baseMet < 6.0) {
        sessionModEquiv = minutes;
      } else {
        sessionModEquiv = minutes * 2;
      }

      totalModerateEquivalent += sessionModEquiv;
      totalRawMet += minutes * baseMet;

      final dateIso = MvCalendar.formatDateIso(
        DateTime.fromMillisecondsSinceEpoch(sess.startedAt),
      );
      activeDaysSet.add(dateIso);

      final isStrength = (kind != null && kind.family == MovementFamily.strength) ||
          sess.kindCode.toUpperCase() == 'BODYWEIGHT' ||
          sess.sessionMode == MvSessionMode.guided ||
          sess.sessionMode == MvSessionMode.structured;

      if (isStrength) {
        strengthDaysSet.add(dateIso);
      }
    }

    final strengthDays = strengthDaysSet.length;
    final activeDaysCount = activeDaysSet.length;

    // 5. Forecast calculation (Only after at least 3 days have passed: currentDayOfWeekSat0 >= 2)
    final bool canForecast = currentDayOfWeekSat0 >= 2 && activeDaysCount > 0;
    double? forecast;
    if (canForecast) {
      final elapsedDays = currentDayOfWeekSat0 + 1;
      final dailyRate = totalModerateEquivalent / elapsedDays;
      forecast = (totalModerateEquivalent + (dailyRate * (7 - elapsedDays))).roundToDouble();
    }

    final progress = MvWeeklyBudgetProgress(
      moderateEquivalentMinutes: totalModerateEquivalent,
      rawMetMinutes: totalRawMet,
      strengthDays: strengthDays,
      targetMin: 150,
      targetOptimal: 300,
      strengthDaysTarget: 2,
      forecastedModerateMinutes: forecast,
      hasEnoughDataForForecast: canForecast,
      currentActiveDays: activeDaysCount,
      targetActiveDays: profile?.daysPerWeek.clamp(1, 7) ?? 2,
    );

    final reasonFa =
        'مجموع معادل متوسط: $totalModerateEquivalent دقیقه از حداقل ۱۵۰ دقیقه و $strengthDays روز قدرتی از ۲ روز.';

    return MvDecision<MvWeeklyBudgetProgress>(
      value: progress,
      reasonFa: reasonFa,
      sources: const ['session_history', 'movement_kinds', 'who_guidelines'],
      confidence: 1.0,
      hasEnoughData: true,
    );
  }
}
