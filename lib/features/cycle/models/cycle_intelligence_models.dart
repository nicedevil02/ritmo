enum PredictionConfidenceLevel { low, medium, high }

class PredictionConfidence {
  const PredictionConfidence({
    required this.level,
    required this.score,
    required this.reasonsFa,
  });

  final PredictionConfidenceLevel level;
  final double score; // 0..1
  final List<String> reasonsFa;
}

class SymptomForecast {
  const SymptomForecast({
    required this.symptomKey,
    required this.likelyCycleDay,
    required this.confidence,
    required this.insightFa,
  });

  final String symptomKey;
  final int likelyCycleDay;
  final double confidence; // 0..1
  final String insightFa;
}

enum BurdenConfidence { low, medium, high }

class BurdenFactor {
  const BurdenFactor({
    required this.code,
    required this.weight,
    required this.labelFa,
  });

  final String code;
  final double weight;
  final String labelFa;
}

class BodyBurdenScore {
  const BodyBurdenScore({
    required this.score,
    required this.level,
    this.confidence = 'MEDIUM',
    this.factors = const [],
    required this.reasonsFa,
  });

  final double score; // 0..100
  final String level; // LOW / MODERATE / HIGH
  final String confidence; // LOW / MEDIUM / HIGH
  final List<BurdenFactor> factors;
  final List<String> reasonsFa;
}

class DataQualityReport {
  const DataQualityReport({
    required this.hasEnoughCycles,
    required this.hasRecentDailyLogs,
    required this.hasForgottenOpenPeriod,
    required this.hasPredictionConfidence,
    required this.recentLogsCount,
    required this.qualityLabelFa,
    required this.warningsFa,
  });

  final bool hasEnoughCycles;
  final bool hasRecentDailyLogs;
  final bool hasForgottenOpenPeriod;
  final bool hasPredictionConfidence;
  final int recentLogsCount;
  final String qualityLabelFa;
  final List<String> warningsFa;
}

enum CycleLoadMode {
  rest,
  lighter,
  balanced,
  higherFocus;

  String get code => switch (this) {
        CycleLoadMode.rest => 'rest',
        CycleLoadMode.lighter => 'lighter',
        CycleLoadMode.balanced => 'balanced',
        CycleLoadMode.higherFocus => 'higher-focus',
      };
}

class CycleAdaptiveAdvice {
  const CycleAdaptiveAdvice({
    required this.loadMode,
    this.mode = CycleLoadMode.balanced,
    required this.energyDelta,
    required this.sessionLengthMultiplier,
    required this.extraBreakMinutesEveryHour,
    required this.recommendationsFa,
  });

  final String loadMode; // lighter / balanced / higher-focus
  final CycleLoadMode mode;
  final int energyDelta;
  final double sessionLengthMultiplier;
  final int extraBreakMinutesEveryHour;
  final List<String> recommendationsFa;
}
