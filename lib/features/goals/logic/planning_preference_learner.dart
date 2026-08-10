import 'package:ritmo/features/goals/logic/personalization_gate.dart';

class LearnedPlanningPreferences {
  const LearnedPlanningPreferences({
    this.prefersEveningDeepWork = false,
    this.preferredDeepBlockMinutes = 60,
    this.eveningDeepWorkConfidence = 0.0,
    this.deepBlockConfidence = 0.0,
  });

  final bool prefersEveningDeepWork;
  final int preferredDeepBlockMinutes;
  final double eveningDeepWorkConfidence;
  final double deepBlockConfidence;

  static const defaultPreferences = LearnedPlanningPreferences();
}

class PlanningPreferenceLearner {
  const PlanningPreferenceLearner({
    this.gate = const PersonalizationGate(),
  });

  final PersonalizationGate gate;

  LearnedPlanningPreferences learnFromHistory({
    required int eveningDeepWorkMoveCount,
    required int totalDeepWorkDecisions,
    required int shrinkTo45Count,
    required int totalBlockAdjustments,
  }) {
    bool prefersEvening = false;
    double eveningConfidence = 0.0;

    if (gate.allows(totalDeepWorkDecisions) && eveningDeepWorkMoveCount >= 2) {
      prefersEvening = (eveningDeepWorkMoveCount / totalDeepWorkDecisions) >= 0.5;
      eveningConfidence = gate.confidenceFor(totalDeepWorkDecisions);
    }

    int preferredBlock = 60;
    double blockConfidence = 0.0;

    if (gate.allows(totalBlockAdjustments) && shrinkTo45Count >= 2) {
      preferredBlock = 45;
      blockConfidence = gate.confidenceFor(totalBlockAdjustments);
    }

    return LearnedPlanningPreferences(
      prefersEveningDeepWork: prefersEvening,
      preferredDeepBlockMinutes: preferredBlock,
      eveningDeepWorkConfidence: eveningConfidence,
      deepBlockConfidence: blockConfidence,
    );
  }
}
