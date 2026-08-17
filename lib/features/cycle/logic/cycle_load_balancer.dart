import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';

class CycleLoadBalanceConstants {
  static const double highBurdenMultiplier = 0.70;
  static const int highBurdenExtraBreaks = 10;
  static const int highBurdenEnergyDelta = -15;

  static const double moderateBurdenMultiplier = 0.85;
  static const int moderateBurdenExtraBreaks = 5;
  static const int moderateBurdenEnergyDelta = -7;

  static const double normalMultiplier = 1.0;
  static const int normalExtraBreaks = 0;
  static const int normalEnergyDelta = 0;
}

class CycleLoadBalancer {
  static CycleAdaptiveAdvice generateAdvice(
    BodyBurdenScore burden, {
    CyclePhase? phase,
  }) {
    if (burden.level == 'HIGH') {
      return const CycleAdaptiveAdvice(
        loadMode: 'lighter',
        mode: CycleLoadMode.lighter,
        energyDelta: CycleLoadBalanceConstants.highBurdenEnergyDelta,
        sessionLengthMultiplier: CycleLoadBalanceConstants.highBurdenMultiplier,
        extraBreakMinutesEveryHour: CycleLoadBalanceConstants.highBurdenExtraBreaks,
        recommendationsFa: [
          'برنامه‌های سنگین امروز را کاهش دهید یا به روزهای دیگر منتقل کنید.',
          'جلسات تمرکز یا مطالعه را به بازه‌های کوتاه‌تر ۳۰ دقیقه‌ای تقسیم کنید.',
          'استراحت‌های کوتاه‌مدت بیشتری در طول روز برنامه‌ریزی کنید.',
          'مصرف آب، چای گرم و مراقبت‌های آرامش‌بخش را اولویت دهید.',
        ],
      );
    } else if (burden.level == 'MODERATE') {
      return const CycleAdaptiveAdvice(
        loadMode: 'balanced',
        mode: CycleLoadMode.balanced,
        energyDelta: CycleLoadBalanceConstants.moderateBurdenEnergyDelta,
        sessionLengthMultiplier: CycleLoadBalanceConstants.moderateBurdenMultiplier,
        extraBreakMinutesEveryHour: CycleLoadBalanceConstants.moderateBurdenExtraBreaks,
        recommendationsFa: [
          'برنامه امروز متوازن است؛ ریتم متناسب و بدون فشار حفظ شود.',
          'در صورت احساس خستگی، ۵ دقیقه استراحت اضافه در ساعت بگیرید.',
          'کارهای فکری مهم‌تر را در ساعات اولیه روز انجام دهید.',
        ],
      );
    } else {
      // If in menstrual phase, never recommend higher-focus
      if (phase == CyclePhase.menstrual) {
        return const CycleAdaptiveAdvice(
          loadMode: 'balanced',
          mode: CycleLoadMode.balanced,
          energyDelta: CycleLoadBalanceConstants.normalEnergyDelta,
          sessionLengthMultiplier: CycleLoadBalanceConstants.normalMultiplier,
          extraBreakMinutesEveryHour: CycleLoadBalanceConstants.normalExtraBreaks,
          recommendationsFa: [
            'وضعیت بدنی در طول دوره قاعدگی آرام و متوازن ارزیابی شده است.',
            'ریتم عادی و بدون تحمیل فشار مضاعف را حفظ کنید.',
          ],
        );
      }

      return const CycleAdaptiveAdvice(
        loadMode: 'higher-focus',
        mode: CycleLoadMode.higherFocus,
        energyDelta: CycleLoadBalanceConstants.normalEnergyDelta,
        sessionLengthMultiplier: CycleLoadBalanceConstants.normalMultiplier,
        extraBreakMinutesEveryHour: CycleLoadBalanceConstants.normalExtraBreaks,
        recommendationsFa: [
          'وضعیت بدنی در ریتم مطلوب قرار دارد.',
          'زمان مناسبی برای پیشبرد اهداف مهم و برنامه‌های پرانرژی است.',
        ],
      );
    }
  }
}

