import 'package:ritmo/core/ai/brief/domain_brief.dart';
import 'package:ritmo/core/analytics/sleep_engine.dart';

class SleepBrief implements DomainBrief {
  SleepBrief({
    required this.sampleSize,
    required this.computedAt,
    required this.avgDurationMinutes,
    required this.avgQuality,
    required this.sleepDebtMinutes,
    required this.consistencyScore,
    this.socialJetlagMinutes,
    this.bestBedtimeWindow,
    this.sleepEnergyCorrelation,
    this.sleepMoodCorrelation,
  });

  @override
  final String domainId = 'sleep';
  
  @override
  final int sampleSize;
  
  @override
  final DateTime computedAt;

  final int? avgDurationMinutes;
  final double? avgQuality;
  final int sleepDebtMinutes;
  final double? consistencyScore;
  final int? socialJetlagMinutes;
  final String? bestBedtimeWindow;
  final double? sleepEnergyCorrelation;
  final double? sleepMoodCorrelation;

  @override
  BriefConfidence get confidence {
    if (sampleSize < 3) return BriefConfidence.none;
    if (sampleSize < 7) return BriefConfidence.low;
    if (sampleSize < 21) return BriefConfidence.medium;
    return BriefConfidence.high;
  }

  @override
  List<String> get fieldNames => [
    'sleep.avgDurationMinutes',
    'sleep.avgQuality',
    'sleep.sleepDebtMinutes',
    'sleep.consistencyScore',
    'sleep.socialJetlagMinutes',
    'sleep.bestBedtimeWindow',
    'sleep.sleepEnergyCorrelation',
    'sleep.sleepMoodCorrelation',
  ];

  @override
  Map<String, Object?> toPromptJson() {
    return {
      'avgDurationMinutes': avgDurationMinutes,
      'avgQuality': avgQuality,
      'sleepDebtMinutes': sleepDebtMinutes,
      'consistencyScore': consistencyScore,
      'socialJetlagMinutes': socialJetlagMinutes,
      'bestBedtimeWindow': bestBedtimeWindow,
      'sleepEnergyCorrelation': sleepEnergyCorrelation,
      'sleepMoodCorrelation': sleepMoodCorrelation,
      'confidence': confidence.name,
    }..removeWhere((key, value) => value == null);
  }

  factory SleepBrief.fromEngine(SleepEngineOutput out, int sampleCount) {
    return SleepBrief(
      sampleSize: sampleCount,
      computedAt: DateTime.now(),
      avgDurationMinutes: out.avgDurationMinutes.toInt(),
      avgQuality: out.avgQuality,
      sleepDebtMinutes: out.sleepDebtMinutes,
      consistencyScore: out.consistencyScore,
      socialJetlagMinutes: null, // Calculated separately if needed
      bestBedtimeWindow: out.bestBedtimeWindow,
      sleepEnergyCorrelation: out.sleepEnergyCorrelation,
      sleepMoodCorrelation: out.sleepMoodCorrelation,
    );
  }
}
