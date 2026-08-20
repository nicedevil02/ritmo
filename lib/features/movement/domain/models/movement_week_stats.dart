import 'package:ritmo/core/utils/persian_digits.dart';

/// دلیل وضعیت سنجهٔ حرکتی
enum MovementMetricReason { ok, noData, partialData, notApplicable }

/// ساختار سنجهٔ آماری حرکت با ذکر اندازه نمونه و قابلیت اتکا (M-67 / P-03)
class MovementMetric<T> {
  const MovementMetric({
    required this.value,
    required this.sampleSize,
    required this.reason,
  });

  const MovementMetric.noData()
      : value = null,
        sampleSize = 0,
        reason = MovementMetricReason.noData;

  final T? value;
  final int sampleSize;
  final MovementMetricReason reason;

  bool get isReliable => reason == MovementMetricReason.ok;
}

/// آمار عملکرد هفتگی حرکت کاربر (P-03 / P-17)
class MovementWeekStats {
  const MovementWeekStats({
    required this.plannedCount,
    required this.doneCount,
    required this.activeStreakDays,
    required this.totalMinutes,
    required this.adherence,
    required this.hasAnyData,
  });

  const MovementWeekStats.empty()
      : plannedCount = 0,
        doneCount = 0,
        activeStreakDays = 0,
        totalMinutes = 0,
        adherence = const MovementMetric.noData(),
        hasAnyData = false;

  final int plannedCount;
  final int doneCount;
  final int activeStreakDays; // روزهای متوالی فعالیت
  final int totalMinutes;
  final MovementMetric<double> adherence; // پایبندی با رعایت حداقل اندازه نمونه
  final bool hasAnyData;

  /// برچسب قرارداد هفتگی (P-17) جایگزین استریک
  String weekContractLabel() {
    if (plannedCount == 0) return '';
    if (doneCount >= plannedCount) return 'هفته‌ات کامله 🎉';
    return 'این هفته: ${toPersianDigits(doneCount)} از ${toPersianDigits(plannedCount)}';
  }
}
