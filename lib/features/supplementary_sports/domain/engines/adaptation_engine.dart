import '../models/models.dart';

/// 7.7 AdaptationEngine: Adapts schedules non-judgmentally upon missed sessions or absence.
class AdaptationEngine {
  const AdaptationEngine();

  /// Evaluates adaptation after a session is skipped.
  MvDecision<MvSlot?> suggestCompensation({
    required MvSlot skippedSlot,
    required List<MvSlot> upcomingSlots,
  }) {
    // Find the next rest day within 72 hours
    final nextRestSlot = upcomingSlots.where((s) => s.isRest).firstOrNull;

    if (nextRestSlot != null) {
      final adapted = nextRestSlot.copyWith(
        slotType: skippedSlot.slotType,
        kindCode: skippedSlot.kindCode,
        focusCodes: skippedSlot.focusCodes,
        targetMinutes: (skippedSlot.targetMinutes * 0.8).round(),
        headlineFa: 'جبران جلسه: ${skippedSlot.headlineFa}',
        coachNoteFa: 'جلسهٔ ملایم‌تر برای حفظ ریتم هفته.',
      );

      return MvDecision<MvSlot?>(
        value: adapted,
        reasonFa:
            'می‌توانی این جلسه را در روز ${MvCalendar.persianWeekdayName(MvCalendar.dateTimeToSat0(MvCalendar.parseDateIso(nextRestSlot.dateIso)))} با زمان کوتاه‌تر انجام دهی.',
        sources: const ['missed_session_policy'],
        confidence: 0.9,
        hasEnoughData: true,
      );
    }

    return const MvDecision<MvSlot?>(
      value: null,
      reasonFa:
          'نیازی به فشار اضافی نیست؛ هفته را طبق برنامهٔ معمول ادامه می‌دهیم.',
      sources: ['schedule_balance'],
      confidence: 1.0,
      hasEnoughData: true,
    );
  }

  /// Evaluates absence and offers a gentle on-ramp.
  MvDecision<String> evaluateAbsence(int inactiveDays) {
    if (inactiveDays >= 14) {
      return const MvDecision<String>(
        value: 'RESET_RECOMMENDED',
        reasonFa:
            'خوش آمدی! برای شروع دوباره، می‌توانیم روزهای برنامه را سبک‌تر و متناسب با شرایط الانت تنظیم کنیم.',
        sources: ['long_inactivity'],
        confidence: 1.0,
        hasEnoughData: true,
      );
    } else if (inactiveDays >= 3) {
      return const MvDecision<String>(
        value: 'MINIMAL_DOSE_OFFER',
        reasonFa:
            'چند روزی فعالیت نداشتی؛ امروز فقط ۱۰ دقیقه حرکت سبک چطور است؟',
        sources: ['short_inactivity'],
        confidence: 0.9,
        hasEnoughData: true,
      );
    }

    return const MvDecision<String>(
      value: 'NORMAL',
      reasonFa: 'ریتم فعالیت برقرار است.',
      sources: ['normal_activity'],
      confidence: 1.0,
      hasEnoughData: true,
    );
  }
}
