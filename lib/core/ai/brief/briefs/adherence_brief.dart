import 'package:ritmo/core/ai/brief/domain_brief.dart';

class AdherenceBrief implements DomainBrief {
  AdherenceBrief({
    required this.sampleSize,
    required this.computedAt,
    required this.adherencePercentage,
    required this.missedRoutinePatternCount,
    this.upcomingTestName,
  });

  @override
  final String domainId = 'health';

  @override
  final int sampleSize;

  @override
  final DateTime computedAt;

  final double adherencePercentage;
  final int missedRoutinePatternCount;
  final String? upcomingTestName;

  @override
  BriefConfidence get confidence {
    if (sampleSize < 1) return BriefConfidence.none;
    if (sampleSize < 3) return BriefConfidence.low;
    if (sampleSize < 7) return BriefConfidence.medium;
    return BriefConfidence.high;
  }

  @override
  List<String> get fieldNames => [
        'health.adherencePercentage',
        'health.missedRoutinePatternCount',
        'health.upcomingTestName',
      ];

  @override
  Map<String, Object?> toPromptJson() {
    return {
      'adherencePercentage': adherencePercentage,
      'missedRoutinePatternCount': missedRoutinePatternCount,
      'upcomingTestName': upcomingTestName,
      'confidence': confidence.name,
    }..removeWhere((key, value) => value == null);
  }
}
