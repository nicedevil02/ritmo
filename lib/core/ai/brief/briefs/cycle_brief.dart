import 'package:ritmo/core/ai/brief/domain_brief.dart';

class CycleBrief implements DomainBrief {
  CycleBrief({
    required this.sampleSize,
    required this.computedAt,
    required this.recordedSymptomLogsCount,
    this.lastLoggedPhase,
  });

  @override
  final String domainId = 'cycle';

  @override
  final int sampleSize;

  @override
  final DateTime computedAt;

  final int recordedSymptomLogsCount;
  final String? lastLoggedPhase;

  @override
  BriefConfidence get confidence {
    if (sampleSize < 1) return BriefConfidence.none;
    if (sampleSize < 3) return BriefConfidence.low;
    if (sampleSize < 7) return BriefConfidence.medium;
    return BriefConfidence.high;
  }

  @override
  List<String> get fieldNames => [
        'cycle.recordedSymptomLogsCount',
        'cycle.lastLoggedPhase',
      ];

  @override
  Map<String, Object?> toPromptJson() {
    return {
      'recordedSymptomLogsCount': recordedSymptomLogsCount,
      'lastLoggedPhase': lastLoggedPhase,
      'confidence': confidence.name,
    }..removeWhere((key, value) => value == null);
  }
}
