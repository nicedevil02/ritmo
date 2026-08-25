import '../models/models.dart';

/// 7.2 ReadinessEngine: Evaluates daily recovery and recommends visible adaptations.
class ReadinessEngine {
  const ReadinessEngine();

  /// Evaluates readiness tier and returns an explainable decision.
  MvDecision<MvReadinessTier> evaluateReadiness({
    MvDailyCheckin? checkin,
    int? energyLevel, // 1..5
    int? sleepMinutes,
    bool isMenstrualPhase = false,
    bool cycleConsentGranted = false,
  }) {
    final sources = <String>[];
    double score = 100.0;
    final reasons = <String>[];

    bool hasData = false;

    // 1. Daily Check-in factors
    if (checkin != null) {
      hasData = true;
      sources.add('checkin');
      if (checkin.energy != null) {
        score -= (5 - checkin.energy!) * 8.0;
      }
      if (checkin.soreness != null && checkin.soreness! > 2) {
        score -= (checkin.soreness! - 2) * 10.0;
        reasons.add('کوفتگی عضلانی');
      }
      if (checkin.fatigue != null && checkin.fatigue! > 2) {
        score -= (checkin.fatigue! - 2) * 10.0;
        reasons.add('خستگی');
      }
      if (checkin.painLevel != null && checkin.painLevel! > 3) {
        score -= (checkin.painLevel! - 3) * 12.0;
        reasons.add('درد موضعی');
      }
    }

    // 2. Direct Energy Level (if checkin didn't have it)
    if (energyLevel != null && (checkin == null || checkin.energy == null)) {
      hasData = true;
      sources.add('energy');
      score -= (5 - energyLevel) * 8.0;
      if (energyLevel <= 2) reasons.add('سطح انرژی پایین');
    }

    // 3. Sleep data
    if (sleepMinutes != null) {
      hasData = true;
      sources.add('sleep');
      if (sleepMinutes < 360) {
        // Less than 6 hours
        score -= 25.0;
        final hours = (sleepMinutes / 60).toStringAsFixed(1);
        reasons.add('خواب کم ($hours ساعت)');
      } else if (sleepMinutes < 420) {
        // Less than 7 hours
        score -= 10.0;
      }
    }

    // 4. Menstrual Phase (Strictly requires explicit cycle consent - Rule 3, Rule 35, AC-12)
    if (isMenstrualPhase && cycleConsentGranted) {
      hasData = true;
      sources.add('cycle');
      score -= 15.0;
      reasons.add('فاز استراحت چرخه');
    }

    // Determine Tier from score
    score = score.clamp(0.0, 100.0);
    final MvReadinessTier tier;
    if (!hasData) {
      tier = MvReadinessTier.light; // Honest fallback without false claim of 100% full
    } else if (score >= 80) {
      tier = MvReadinessTier.full;
    } else if (score >= 60) {
      tier = MvReadinessTier.light;
    } else if (score >= 40) {
      tier = MvReadinessTier.minimal;
    } else {
      tier = MvReadinessTier.rest;
    }

    String reasonFa;
    if (!hasData) {
      reasonFa = 'هنوز دادهٔ کافی برای سنجش آمادگی امروز ثبت نشده است. با یک پاسخ کوتاه وضعیتت را مشخص کن.';
    } else if (tier == MvReadinessTier.full) {
      reasonFa = 'آمادگی بدنی برای تمرین طبق برنامه در سطح عالی قرار دارد.';
    } else {
      final reasonText = reasons.isEmpty ? 'بررسی شرایط کلی' : reasons.join(' و ');
      switch (tier) {
        case MvReadinessTier.light:
          reasonFa = 'به علت $reasonText، شدت تمرین امروز کمی ملایم‌تر تنظیم شد.';
          break;
        case MvReadinessTier.minimal:
          reasonFa = 'به علت $reasonText، امروز تمرین در قالب «حداقل مؤثر ۱۰ دقیقه‌ای» پیشنهاد می‌شود.';
          break;
        case MvReadinessTier.rest:
          reasonFa = 'به علت $reasonText، امروز استراحت و کشش سبک بهترین انتخاب برای ریکاوری است.';
          break;
        case MvReadinessTier.full:
          reasonFa = 'آمادگی کامل برای جلسه امروز.';
          break;
      }
    }

    return MvDecision<MvReadinessTier>(
      value: tier,
      reasonFa: reasonFa,
      sources: sources,
      confidence: hasData ? 0.9 : 0.4,
      hasEnoughData: hasData,
    );
  }
}
