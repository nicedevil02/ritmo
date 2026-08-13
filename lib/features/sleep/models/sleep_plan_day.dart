/// نتیجهٔ یک شب از برنامهٔ خواب — enum بسته (سند «مسیر خواب»، بخش ۲).
enum SleepPlanOutcome { pending, hit, miss, hold, freeNight, cycleHold, noData }

/// یک شب از برنامهٔ خواب — مدل جدول `sleep_plan_days`.
class SleepPlanDay {
  const SleepPlanDay({
    required this.programId,
    required this.date,
    required this.plannedBedtimeMin,
    required this.plannedWakeMin,
    this.actualBedtimeMin,
    this.actualWakeMin,
    this.outcome = SleepPlanOutcome.pending,
  });

  final String programId;

  /// dayKey روزی که شبش خوابیده‌ای (هم‌کنوانسیون با `bedtime_diagnostics.date`).
  final String date;

  /// پلهٔ برنامه‌ریزی‌شده — دقیقه از روز (۰ تا ۱۴۳۹).
  final int plannedBedtimeMin;
  final int plannedWakeMin;

  /// استخراج‌شده از لاگ واقعی هنگام settle — دقیقه از روز.
  final int? actualBedtimeMin;
  final int? actualWakeMin;
  final SleepPlanOutcome outcome;

  bool get isEvaluated =>
      outcome == SleepPlanOutcome.hit || outcome == SleepPlanOutcome.miss;

  factory SleepPlanDay.fromMap(Map<String, dynamic> map) {
    return SleepPlanDay(
      programId: map['programId'] as String,
      date: map['date'] as String,
      plannedBedtimeMin: map['plannedBedtimeMin'] as int? ?? 0,
      plannedWakeMin: map['plannedWakeMin'] as int? ?? 0,
      actualBedtimeMin: map['actualBedtimeMin'] as int?,
      actualWakeMin: map['actualWakeMin'] as int?,
      outcome: SleepPlanOutcome.values
              .asNameMap()[map['outcome'] as String? ?? ''] ??
          SleepPlanOutcome.pending,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'programId': programId,
      'date': date,
      'plannedBedtimeMin': plannedBedtimeMin,
      'plannedWakeMin': plannedWakeMin,
      'actualBedtimeMin': actualBedtimeMin,
      'actualWakeMin': actualWakeMin,
      'outcome': outcome.name,
    };
  }

  SleepPlanDay copyWith({
    int? actualBedtimeMin,
    int? actualWakeMin,
    SleepPlanOutcome? outcome,
  }) {
    return SleepPlanDay(
      programId: programId,
      date: date,
      plannedBedtimeMin: plannedBedtimeMin,
      plannedWakeMin: plannedWakeMin,
      actualBedtimeMin: actualBedtimeMin ?? this.actualBedtimeMin,
      actualWakeMin: actualWakeMin ?? this.actualWakeMin,
      outcome: outcome ?? this.outcome,
    );
  }
}
