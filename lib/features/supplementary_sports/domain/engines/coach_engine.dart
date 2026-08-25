import '../models/models.dart';

/// Coach Recommendation Message.
class MvCoachTip {
  final String textFa;
  final bool isAiGenerated;
  final String? sourceContext;

  const MvCoachTip({
    required this.textFa,
    this.isAiGenerated = false,
    this.sourceContext,
  });
}

/// 7.10 CoachEngine: Generates contextual coaching advice and safety tips.
class CoachEngine {
  const CoachEngine();

  /// Generates contextual advice based on profile, readiness and current slot.
  MvDecision<MvCoachTip> generateTip({
    required MvUserProfile profile,
    required MvSlot slot,
    MvReadinessTier readiness = MvReadinessTier.full,
    bool isOnline = true,
  }) {
    String tipText;

    if (readiness == MvReadinessTier.minimal || readiness == MvReadinessTier.rest) {
      tipText = 'امروز به بدنت گوش بده؛ حرکات کششی و حفظ فرم صحیح بالاترین اولویت را دارد.';
    } else if (slot.intensityTier == MvIntensityTier.hard) {
      tipText = 'در ست‌های پایانی روی تنفس عمیق و انقباض آرام تمرکز کن تا بیشترین بهره را ببری.';
    } else if (profile.physicalLimitations.isNotEmpty) {
      tipText = 'به دلیل محدودیت در ${profile.physicalLimitations.join("، ")}، از حرکات پرضربه خودداری شده است.';
    } else {
      tipText = 'نوشیدن آب کافی و گرم کردن ۵ دقیقه‌ای قبل از شروع، کیفیت تمرینت را دوچندان می‌کند.';
    }

    final tip = MvCoachTip(
      textFa: tipText,
      isAiGenerated: false, // Honest flag for rule-based deterministic advice
      sourceContext: 'smart_rules',
    );

    return MvDecision<MvCoachTip>(
      value: tip,
      reasonFa: 'پیشنهاد مربی بر اساس وضعیت آمادگی و نوع جلسهٔ امروز.',
      sources: const ['coach_rules'],
      confidence: 1.0,
      hasEnoughData: true,
    );
  }
}
