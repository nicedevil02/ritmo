// CycleLoadBalancer (C-31, C-41: Adaptive workload advice & code-based contract)
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
        extraBreakMinutesEveryHour:
            CycleLoadBalanceConstants.highBurdenExtraBreaks,
        recommendationCodes: [
          'reduce_heavy_workload',
          'split_focus_sessions',
          'plan_more_frequent_breaks',
          'prioritize_comfort_hydration',
        ],
      );
    } else if (burden.level == 'MODERATE') {
      return const CycleAdaptiveAdvice(
        loadMode: 'balanced',
        mode: CycleLoadMode.balanced,
        energyDelta: CycleLoadBalanceConstants.moderateBurdenEnergyDelta,
        sessionLengthMultiplier:
            CycleLoadBalanceConstants.moderateBurdenMultiplier,
        extraBreakMinutesEveryHour:
            CycleLoadBalanceConstants.moderateBurdenExtraBreaks,
        recommendationCodes: [
          'maintain_balanced_rhythm',
          'take_extra_five_min_break',
          'do_deep_work_early',
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
          extraBreakMinutesEveryHour:
              CycleLoadBalanceConstants.normalExtraBreaks,
          recommendationCodes: [
            'gentle_menstrual_rhythm',
            'avoid_unnecessary_pressure',
          ],
        );
      }

      return const CycleAdaptiveAdvice(
        loadMode: 'higher-focus',
        mode: CycleLoadMode.higherFocus,
        energyDelta: CycleLoadBalanceConstants.normalEnergyDelta,
        sessionLengthMultiplier: CycleLoadBalanceConstants.normalMultiplier,
        extraBreakMinutesEveryHour: CycleLoadBalanceConstants.normalExtraBreaks,
        recommendationCodes: [
          'optimal_physical_rhythm',
          'ideal_for_demanding_tasks',
        ],
      );
    }
  }
}
