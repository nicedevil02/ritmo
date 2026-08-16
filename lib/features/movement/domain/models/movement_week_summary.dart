/// مدل خلاصهٔ ۳ متریکی هفته (متریک چهارم ممنوع)
class MovementWeekSummary {
  const MovementWeekSummary({
    this.completedCount = 0,
    this.plannedCount = 0,
    this.activeMinutes = 0,
    this.recoveryDaysCount = 0,
  });

  final int completedCount;
  final int plannedCount;
  final int activeMinutes;
  final int recoveryDaysCount;

  bool get hasAnyCompleted => completedCount > 0 || activeMinutes > 0;
}
