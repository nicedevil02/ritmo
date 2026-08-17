// Cycle Intelligence Models (C-41: Clean domain contracts without hardcoded strings)

enum PredictionConfidenceLevel { low, medium, high }

class PredictionConfidence {
  const PredictionConfidence({
    required this.level,
    required this.score,
    this.reasonCodes = const [],
    List<String>? reasonsFa,
  }) : _reasonsFa = reasonsFa;

  final PredictionConfidenceLevel level;
  final double score; // 0..1
  final List<String> reasonCodes;
  final List<String>? _reasonsFa;

  List<String> get reasonsFa => _reasonsFa ?? reasonCodes;
  List<String> get reasons => reasonCodes;
}

class SymptomForecast {
  const SymptomForecast({
    required this.symptomKey,
    required this.likelyCycleDay,
    required this.confidence,
    String? insightFa,
  }) : _insightFa = insightFa;

  final String symptomKey;
  final int likelyCycleDay;
  final double confidence; // 0..1
  final String? _insightFa;

  String get insightFa => _insightFa ?? symptomKey;
}

enum BurdenConfidence { low, medium, high }

class BurdenFactor {
  const BurdenFactor({
    required this.code,
    required this.weight,
    String? labelFa,
  }) : _labelFa = labelFa;

  final String code;
  final double weight;
  final String? _labelFa;

  String get labelFa => _labelFa ?? code;
  String get label => _labelFa ?? code;
}

class BodyBurdenScore {
  const BodyBurdenScore({
    required this.score,
    required this.level,
    this.confidence = 'MEDIUM',
    this.factors = const [],
    this.reasonCodes = const [],
    List<String>? reasonsFa,
  }) : _reasonsFa = reasonsFa;

  final double score; // 0..100
  final String level; // LOW / MODERATE / HIGH
  final String confidence; // LOW / MEDIUM / HIGH
  final List<BurdenFactor> factors;
  final List<String> reasonCodes;
  final List<String>? _reasonsFa;

  List<String> get reasonsFa => _reasonsFa ?? reasonCodes;
  List<String> get reasons => reasonCodes;
}

class DataQualityReport {
  const DataQualityReport({
    required this.hasEnoughCycles,
    required this.hasRecentDailyLogs,
    required this.hasForgottenOpenPeriod,
    required this.hasPredictionConfidence,
    required this.recentLogsCount,
    this.qualityLevel = 'HIGH',
    this.warningCodes = const [],
    String? qualityLabelFa,
    List<String>? warningsFa,
  })  : _qualityLabelFa = qualityLabelFa,
        _warningsFa = warningsFa;

  final bool hasEnoughCycles;
  final bool hasRecentDailyLogs;
  final bool hasForgottenOpenPeriod;
  final bool hasPredictionConfidence;
  final int recentLogsCount;
  final String qualityLevel;
  final List<String> warningCodes;
  final String? _qualityLabelFa;
  final List<String>? _warningsFa;

  String get qualityLabelFa => _qualityLabelFa ?? qualityLevel;
  List<String> get warningsFa => _warningsFa ?? warningCodes;
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
    this.recommendationCodes = const [],
    List<String>? recommendationsFa,
  }) : _recommendationsFa = recommendationsFa;

  final String loadMode; // lighter / balanced / higher-focus
  final CycleLoadMode mode;
  final int energyDelta;
  final double sessionLengthMultiplier;
  final int extraBreakMinutesEveryHour;
  final List<String> recommendationCodes;
  final List<String>? _recommendationsFa;

  List<String> get recommendationsFa => _recommendationsFa ?? recommendationCodes;
}
