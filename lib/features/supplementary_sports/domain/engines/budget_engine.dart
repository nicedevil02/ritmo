import '../models/models.dart';

/// Weekly Activity Progress Summary.
class MvWeeklyBudgetProgress {
  final double targetMetMinutes;
  final int targetActiveDays;
  final double currentMetMinutes;
  final int currentActiveDays;
  final double? forecastedMetMinutes;
  final bool hasEnoughDataForForecast;

  const MvWeeklyBudgetProgress({
    required this.targetMetMinutes,
    required this.targetActiveDays,
    required this.currentMetMinutes,
    required this.currentActiveDays,
    this.forecastedMetMinutes,
    this.hasEnoughDataForForecast = false,
  });

  double get percentage => targetMetMinutes > 0
      ? (currentMetMinutes / targetMetMinutes).clamp(0.0, 1.5)
      : 0.0;
}

/// 7.8 BudgetEngine: Evaluates weekly active minutes (MET-min) budget and progress.
class BudgetEngine {
  const BudgetEngine();

  /// Calculates weekly target and accumulated progress.
  MvDecision<MvWeeklyBudgetProgress> calculateWeeklyProgress({
    required MvUserProfile profile,
    required List<MvSession> weekCompletedSessions,
    required int currentDayOfWeekSat0, // 0=Sat .. 6=Fri
  }) {
    // 1. Calculate target
    final daysTarget = profile.daysPerWeek.clamp(1, 7);
    final targetMetMinutes = daysTarget * 30.0 * 5.0; // standard 30 min at moderate MET 5.0 = 150 MET-min per session

    // 2. Aggregate completed sessions
    double currentMet = 0.0;
    final activeDaysSet = <String>{};

    for (final sess in weekCompletedSessions) {
      final minutes = sess.elapsedMinutes > 0 ? sess.elapsedMinutes : 30;
      currentMet += minutes * 5.0; // standard MET factor
      final dateIso = MvCalendar.formatDateIso(DateTime.fromMillisecondsSinceEpoch(sess.startedAt));
      activeDaysSet.add(dateIso);
    }

    final activeDaysCount = activeDaysSet.length;

    // 3. Forecast calculation (Only after day 3, Rule 7)
    final bool canForecast = currentDayOfWeekSat0 >= 2 && activeDaysCount > 0;
    double? forecast;
    if (canForecast) {
      final elapsedDays = currentDayOfWeekSat0 + 1;
      final dailyRate = currentMet / elapsedDays;
      forecast = currentMet + (dailyRate * (7 - elapsedDays));
    }

    final progress = MvWeeklyBudgetProgress(
      targetMetMinutes: targetMetMinutes,
      targetActiveDays: daysTarget,
      currentMetMinutes: currentMet,
      currentActiveDays: activeDaysCount,
      forecastedMetMinutes: forecast,
      hasEnoughDataForForecast: canForecast,
    );

    final reasonFa = '$activeDaysCount از $daysTarget روز فعال این هفته تکمیل شده است.';

    return MvDecision<MvWeeklyBudgetProgress>(
      value: progress,
      reasonFa: reasonFa,
      sources: const ['profile', 'session_history'],
      confidence: 1.0,
      hasEnoughData: true,
    );
  }
}
