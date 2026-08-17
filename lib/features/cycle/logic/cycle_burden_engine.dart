import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:ritmo/features/cycle/models/cycle_models.dart';

class CycleBurdenWeights {
  static const double base = 5.0;
  static const double phaseMenstrual = 25.0;
  static const double phaseLuteal = 15.0;
  static const double flowHeavy = 20.0;
  static const double flowMedium = 10.0;
  static const double maxSymptoms = 20.0;
  static const double perSymptom = 5.0;
  static const double lowEnergy = 15.0;
  static const double sleepDeficit = 15.0;
}

class CycleBurdenEngine {
  static BodyBurdenScore calculateBurden({
    required CyclePhase phase,
    required int dayOfPeriod,
    dynamic flowIntensity, // String or CycleFlowLevel
    required List<String> loggedSymptoms,
    required String? energyTag,
    required double? sleepHours,
  }) {
    var score = CycleBurdenWeights.base;
    final reasonsFa = <String>[];
    final factors = <BurdenFactor>[];

    // 1. Phase impact
    if (phase == CyclePhase.menstrual) {
      score += CycleBurdenWeights.phaseMenstrual;
      factors.add(const BurdenFactor(
        code: 'phase_menstrual',
        weight: CycleBurdenWeights.phaseMenstrual,
        labelFa: 'دوره فعال قاعدگی',
      ));
      reasonsFa.add('دوره فعال قاعدگی');
    } else if (phase == CyclePhase.luteal) {
      score += CycleBurdenWeights.phaseLuteal;
      factors.add(const BurdenFactor(
        code: 'phase_luteal',
        weight: CycleBurdenWeights.phaseLuteal,
        labelFa: 'فاز لوتئال (قبل از دوره)',
      ));
      reasonsFa.add('فاز لوتئال (قبل از دوره)');
    }

    // 2. Flow intensity impact
    final flowEnum = flowIntensity is CycleFlowLevel
        ? flowIntensity
        : CycleFlowLevel.fromDb(flowIntensity?.toString());

    if (flowEnum == CycleFlowLevel.heavy) {
      score += CycleBurdenWeights.flowHeavy;
      factors.add(const BurdenFactor(
        code: 'flow_heavy',
        weight: CycleBurdenWeights.flowHeavy,
        labelFa: 'خونریزی شدید',
      ));
      reasonsFa.add('خونریزی شدید');
    } else if (flowEnum == CycleFlowLevel.medium) {
      score += CycleBurdenWeights.flowMedium;
      factors.add(const BurdenFactor(
        code: 'flow_medium',
        weight: CycleBurdenWeights.flowMedium,
        labelFa: 'خونریزی متوسط',
      ));
      reasonsFa.add('خونریزی متوسط');
    }

    // 3. Symptoms impact
    final validSymptoms = loggedSymptoms.where((s) => s.trim().isNotEmpty).toList();
    if (validSymptoms.isNotEmpty) {
      final symScore = (validSymptoms.length * CycleBurdenWeights.perSymptom)
          .clamp(0.0, CycleBurdenWeights.maxSymptoms);
      score += symScore;
      factors.add(BurdenFactor(
        code: 'symptoms',
        weight: symScore,
        labelFa: '${validSymptoms.length} علامت بدنی ثبت شده',
      ));
      reasonsFa.add('${validSymptoms.length} علامت بدنی ثبت شده');
    }

    // 4. Energy tag impact
    final normalizedEnergy = energyTag?.trim().toUpperCase();
    if (normalizedEnergy == 'LOW') {
      score += CycleBurdenWeights.lowEnergy;
      factors.add(const BurdenFactor(
        code: 'energy_low',
        weight: CycleBurdenWeights.lowEnergy,
        labelFa: 'سطح انرژی پایین',
      ));
      reasonsFa.add('سطح انرژی پایین');
    }

    // 5. Sleep hours impact (< 6.0 hrs)
    if (sleepHours != null && sleepHours < 6.0) {
      score += CycleBurdenWeights.sleepDeficit;
      factors.add(const BurdenFactor(
        code: 'sleep_deficit',
        weight: CycleBurdenWeights.sleepDeficit,
        labelFa: 'کمبود خواب دیشب',
      ));
      reasonsFa.add('کمبود خواب دیشب');
    }

    // Determine data confidence
    final hasContextData = validSymptoms.isNotEmpty || normalizedEnergy != null || sleepHours != null;
    final confidence = hasContextData ? 'HIGH' : 'LOW';

    // Without user-reported symptom/energy/sleep context, cap at MODERATE
    var finalScore = score.clamp(0.0, 100.0);
    if (!hasContextData && finalScore >= 60.0) {
      finalScore = 55.0; // Keep at upper-moderate
    }

    final level = finalScore >= 60.0
        ? 'HIGH'
        : (finalScore >= 35.0 ? 'MODERATE' : 'LOW');

    return BodyBurdenScore(
      score: finalScore,
      level: level,
      confidence: confidence,
      factors: factors,
      reasonsFa: reasonsFa,
    );
  }
}
