import 'package:ritmo/core/ai/brief/domain_brief.dart';

class WorshipBrief implements DomainBrief {
  WorshipBrief({
    required this.sampleSize,
    required this.computedAt,
    required this.activePracticesCount,
    required this.totalDebtsCount,
    this.consistencyScore,
    this.upcomingOccasion,
  });

  @override
  final String domainId = 'worship';

  @override
  final int sampleSize;

  @override
  final DateTime computedAt;

  final int activePracticesCount;
  final int totalDebtsCount;
  final double? consistencyScore;
  final String? upcomingOccasion;

  @override
  BriefConfidence get confidence {
    if (sampleSize < 1) return BriefConfidence.none;
    if (sampleSize < 3) return BriefConfidence.low;
    if (sampleSize < 7) return BriefConfidence.medium;
    return BriefConfidence.high;
  }

  @override
  List<String> get fieldNames => [
        'worship.activePracticesCount',
        'worship.totalDebtsCount',
        'worship.consistencyScore',
        'worship.upcomingOccasion',
      ];

  @override
  Map<String, Object?> toPromptJson() {
    return {
      'activePracticesCount': activePracticesCount,
      'totalDebtsCount': totalDebtsCount,
      'consistencyScore': consistencyScore,
      'upcomingOccasion': upcomingOccasion,
      'confidence': confidence.name,
    }..removeWhere((key, value) => value == null);
  }
}
