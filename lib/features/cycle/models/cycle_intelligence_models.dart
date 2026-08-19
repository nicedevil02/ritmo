// Cycle Intelligence Models (C-41: Clean domain contracts without hardcoded strings)
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';

enum PredictionConfidenceLevel { low, medium, high }

class PredictionConfidence {
  const PredictionConfidence({
    required this.level,
    required this.score,
    this.reasonCodes = const [],
    this.reasonsFa,
  });

  final PredictionConfidenceLevel level;
  final double score; // 0..1
  final List<String> reasonCodes;
  final List<String>? reasonsFa;

  List<String> get reasons => reasonsFa ?? reasonCodes;
}

class SymptomForecast {
  const SymptomForecast({
    required this.symptomKey,
    required this.likelyCycleDay,
    required this.confidence,
    this.insightFa,
  });

  final String symptomKey;
  final int likelyCycleDay;
  final double confidence; // 0..1
  final String? insightFa;
}

enum BurdenConfidence { low, medium, high }

class BurdenFactor {
  const BurdenFactor({required this.code, required this.weight, this.labelFa});

  final String code;
  final double weight;
  final String? labelFa;

  String get label => labelFa ?? code;
}

class BodyBurdenScore {
  const BodyBurdenScore({
    required this.score,
    required this.level,
    this.confidence = 'MEDIUM',
    this.factors = const [],
    this.reasonCodes = const [],
    this.reasonsFa,
  });

  final double score; // 0..100
  final String level; // LOW / MODERATE / HIGH
  final String confidence; // LOW / MEDIUM / HIGH
  final List<BurdenFactor> factors;
  final List<String> reasonCodes;
  final List<String>? reasonsFa;

  List<String> get reasons => reasonsFa ?? reasonCodes;
}

class DataQualityReport {
  static const int forgottenOpenPeriodThresholdDays =
      CycleSettings.forgottenOpenPeriodDays;

  const DataQualityReport({
    required this.hasEnoughCycles,
    required this.hasRecentDailyLogs,
    required this.hasForgottenOpenPeriod,
    required this.hasPredictionConfidence,
    required this.recentLogsCount,
    this.qualityLevel = 'HIGH',
    this.warningCodes = const [],
    this.qualityLabelFa,
    this.warningsFa,
  });

  final bool hasEnoughCycles;
  final bool hasRecentDailyLogs;
  final bool hasForgottenOpenPeriod;
  final bool hasPredictionConfidence;
  final int recentLogsCount;
  final String qualityLevel;
  final List<String> warningCodes;
  final String? qualityLabelFa;
  final List<String>? warningsFa;
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
    this.recommendationsFa,
  });

  final String loadMode; // lighter / balanced / higher-focus
  final CycleLoadMode mode;
  final int energyDelta;
  final double sessionLengthMultiplier;
  final int extraBreakMinutesEveryHour;
  final List<String> recommendationCodes;
  final List<String>? recommendationsFa;
}
