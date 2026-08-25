import '../models/models.dart';

/// 7.3 PlanEngine: Generates and harmonizes weekly workout and movement plans.
///
/// Merges legacy generators into one single, explainable brain.
class PlanEngine {
  const PlanEngine();

  /// Generates 7 slots for the week starting at [weekSaturday].
  MvDecision<List<MvSlot>> generateWeekPlan({
    required MvUserProfile profile,
    required DateTime weekSaturday,
    List<MvSlot> existingSlots = const [],
    int totalCycleWeeks = 4,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final weekDays = MvCalendar.getWeekDays(weekSaturday);
    final startDate = profile.programStartDate != null
        ? MvCalendar.parseDateIso(profile.programStartDate!)
        : weekSaturday;
    final cycleWeek = MvCalendar.cycleWeekFor(
      targetDate: weekSaturday,
      programStartDate: startDate,
      totalWeeks: totalCycleWeeks,
    );
    final isDeload = MvCalendar.isDeloadWeek(
      cycleWeek,
      deloadEveryNWeeks: profile.deloadEveryNWeeks,
    );

    final targetMinutes = _parseDuration(profile.sessionDuration, isDeload);
    final slots = <MvSlot>[];

    // Determine muscle focus sequence based on daysPerWeek and split pattern
    final musclePlan = _buildMuscleDistribution(profile.trainingDays, isDeload);

    for (int i = 0; i < 7; i++) {
      final dayDate = weekDays[i];
      final dayIso = MvCalendar.formatDateIso(dayDate);
      final sat0 = i;

      // Check if there is an existing locked slot for this day
      final existingLocked = existingSlots.where((s) => s.dateIso == dayIso && s.isLocked).firstOrNull;
      if (existingLocked != null) {
        slots.add(existingLocked);
        continue;
      }

      final isTrainingDay = profile.trainingDays.contains(sat0);
      if (!isTrainingDay) {
        // Rest / Active Recovery day
        slots.add(
          MvSlot(
            id: 'slot_${dayIso}_rest',
            dateIso: dayIso,
            cycleWeek: cycleWeek,
            slotType: MvSlotType.rest,
            targetMinutes: 0,
            intensityTier: MvIntensityTier.light,
            headlineFa: 'روز استراحت و ریکاوری',
            coachNoteFa: 'به عضلاتت فرصت بازسازی بده یا با پیاده‌روی سبک جریان خون را تقویت کن.',
            source: 'GENERATED',
            status: MvSlotStatus.planned,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        // Training day
        final dayFocus = musclePlan[sat0] ?? ['FULL_BODY'];
        final headline = _generateHeadline(dayFocus, isDeload);
        final intensity = isDeload ? MvIntensityTier.light : profile.defaultIntensity;

        slots.add(
          MvSlot(
            id: 'slot_$dayIso',
            dateIso: dayIso,
            cycleWeek: cycleWeek,
            slotType: MvSlotType.strength,
            kindCode: 'bodyweight',
            focusCodes: dayFocus,
            targetMinutes: targetMinutes,
            intensityTier: intensity,
            targetRpe: intensity.targetRpe,
            headlineFa: headline,
            coachNoteFa: isDeload
                ? 'این هفته سبک‌تر تمرین می‌کنیم تا بدنت ریکاوری شود و برای هفتهٔ بعد آماده باشی.'
                : 'تمرکز روی کنترل حرکت و انقباض مناسب عضلات.',
            source: 'GENERATED',
            status: MvSlotStatus.planned,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }

    String reasonFa = 'برنامهٔ هفتهٔ $cycleWeek با ${profile.trainingDays.length} روز فعال تنظیم شد.';
    if (isDeload) {
      reasonFa += ' این هفته به عنوان «هفتهٔ سبک» با حجم کمتر تنظیم شده است.';
    }

    return MvDecision<List<MvSlot>>(
      value: slots,
      reasonFa: reasonFa,
      sources: const ['profile', 'calendar'],
      confidence: 1.0,
      hasEnoughData: true,
    );
  }

  int _parseDuration(String duration, bool isDeload) {
    int baseMinutes = 30;
    switch (duration.toLowerCase()) {
      case 'short':
      case '15':
        baseMinutes = 15;
        break;
      case 'long':
      case '45':
      case '60':
        baseMinutes = 45;
        break;
      case 'medium':
      case '30':
      default:
        baseMinutes = 30;
    }
    if (isDeload) {
      baseMinutes = (baseMinutes * 0.6).round().clamp(10, 45);
    }
    return baseMinutes;
  }

  Map<int, List<String>> _buildMuscleDistribution(List<int> trainingDays, bool isDeload) {
    final map = <int, List<String>>{};
    final count = trainingDays.length;

    if (count <= 2) {
      for (final day in trainingDays) {
        map[day] = ['FULL_BODY'];
      }
    } else if (count == 3) {
      map[trainingDays[0]] = ['CHEST', 'TRICEPS', 'SHOULDER']; // Push / Upper
      map[trainingDays[1]] = ['QUADS_GLUTES', 'HAMSTRINGS', 'CALVES']; // Lower
      map[trainingDays[2]] = ['BACK', 'BICEPS', 'CORE']; // Pull / Back
    } else if (count == 4) {
      map[trainingDays[0]] = ['UPPER'];
      map[trainingDays[1]] = ['LOWER'];
      map[trainingDays[2]] = ['UPPER'];
      map[trainingDays[3]] = ['LOWER', 'CORE'];
    } else {
      for (int i = 0; i < count; i++) {
        final day = trainingDays[i];
        if (i % 3 == 0) map[day] = ['UPPER'];
        if (i % 3 == 1) map[day] = ['LOWER'];
        if (i % 3 == 2) map[day] = ['CORE', 'CARDIO'];
      }
    }
    return map;
  }

  String _generateHeadline(List<String> focus, bool isDeload) {
    final prefix = isDeload ? 'سبک: ' : '';
    if (focus.contains('FULL_BODY')) return '$prefixتمرین کل بدن';
    if (focus.contains('QUADS_GLUTES') || focus.contains('LOWER')) return '$prefixقدرت و استقامت پایین‌تنه';
    if (focus.contains('CHEST') || focus.contains('UPPER')) return '$prefixقدرت بالاتنه و سینه';
    if (focus.contains('BACK')) return '$prefixتقویت عضلات پشت و بازو';
    if (focus.contains('CORE')) return '$prefixتمرین مرکز بدن و شکم';
    return '$prefixجلسهٔ قدرتی';
  }
}
