import 'capacity_models.dart';

/// ظرفیت واقعی ≠ شکاف خام تقویم.
/// usable = waking - occupied - transitionBuffer - restFloor
/// commit = usable × (1 - reserveRatio) × executionFactor
/// همهٔ قواعد قابل‌تست و deterministic؛ بدون LLM.
class WeekCapacityCalculator {
  const WeekCapacityCalculator();

  /// ۱۵ دقیقه بافر جابه‌جایی بین بلوک‌های برنامه در روز
  static const int transitionBufferPerBlock = 15;

  /// ۶۰ دقیقه کف استراحت اجباری روزانه (بدون برنامه‌ریزی)
  static const int minRestFloorMinutes = 60;

  /// ۳۰ دقیقه حداقل ظرفیت قابل‌تعهد در روز (زیر این روز سبک اعلام می‌شود)
  static const int minCommittablePerDay = 30;

  DayCapacity compute({
    required DayLoad load,
    required int wakingMinutes,
    required ReserveProfile profile,
    required double executionFactor,
  }) {
    final buffers = load.fixedCount * transitionBufferPerBlock;
    var raw = wakingMinutes - load.occupiedMinutes;
    if (raw < 0) raw = 0;

    var usable = raw - buffers - minRestFloorMinutes;
    if (usable < 0) usable = 0;

    var factor = executionFactor.clamp(0.4, 1.1);
    if (load.isTravelDay) factor *= 0.5;
    if (load.userMarkedLight) factor *= 0.4;

    var committable = (usable * (1 - profile.reserveRatio) * factor).round();
    if (usable > 0 && committable < minCommittablePerDay) {
      committable = usable < minCommittablePerDay ? usable : minCommittablePerDay;
    }
    return DayCapacity(
      dayKey: load.dayKey,
      rawFreeMinutes: raw,
      usableMinutes: usable,
      committableMinutes: committable,
    );
  }

  List<DayCapacity> computeWeek({
    required List<DayLoad> loads,
    required int wakingMinutes,
    required ReserveProfile profile,
    required double executionFactor,
  }) {
    return loads
        .map((l) => compute(
            load: l,
            wakingMinutes: wakingMinutes,
            profile: profile,
            executionFactor: executionFactor))
        .toList();
  }
}
