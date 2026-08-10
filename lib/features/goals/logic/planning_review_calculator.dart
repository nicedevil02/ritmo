/// محاسبهٔ سنجه‌های یک چرخه در پایان بازه — بدون LLM.
class CycleReviewStats {
  const CycleReviewStats({
    required this.plannedMinutes,
    required this.completedMinutes,
    required this.movedMinutes,
    required this.droppedMinutes,
    required this.calibrationScore,
  });

  final int plannedMinutes;
  final int completedMinutes;
  final int movedMinutes;
  final int droppedMinutes;

  /// دقت برنامه‌ریزی: completed/planned با کف‌گذاری روی دادهٔ کم.
  /// null یعنی «داده کافی نیست» — هرگز صفر نمایش داده نمی‌شود.
  final double? calibrationScore;
}

class PlanningReviewCalculator {
  const PlanningReviewCalculator();

  CycleReviewStats compute({
    required int plannedMinutes,
    required int completedMinutes,
    required int movedMinutes,
    required int droppedMinutes,
  }) {
    double? score;
    if (plannedMinutes >= 120) {
      score = completedMinutes / plannedMinutes;
      if (score > 1.0) score = 1.0;
    }
    return CycleReviewStats(
      plannedMinutes: plannedMinutes,
      completedMinutes: completedMinutes,
      movedMinutes: movedMinutes,
      droppedMinutes: droppedMinutes,
      calibrationScore: score,
    );
  }
}
