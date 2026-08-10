import 'package:ritmo/core/ai/brief/domain_brief.dart';

class SportsBrief implements DomainBrief {
  SportsBrief({
    required this.sampleSize,
    required this.computedAt,
    required this.sessionsLoggedThisWeek,
    this.avgSessionDurationMinutes,
    this.recoveryScore,
    this.primaryFocusArea,
  });

  @override
  final String domainId = 'sports';

  @override
  final int sampleSize;

  @override
  final DateTime computedAt;

  final int sessionsLoggedThisWeek;
  final int? avgSessionDurationMinutes;
  final double? recoveryScore;
  final String? primaryFocusArea;

  @override
  BriefConfidence get confidence {
    if (sampleSize < 1) return BriefConfidence.none;
    if (sampleSize < 3) return BriefConfidence.low;
    if (sampleSize < 7) return BriefConfidence.medium;
    return BriefConfidence.high;
  }

  @override
  List<String> get fieldNames => [
        'sports.sessionsLoggedThisWeek',
        'sports.avgSessionDurationMinutes',
        'sports.recoveryScore',
        'sports.primaryFocusArea',
      ];

  @override
  Map<String, Object?> toPromptJson() {
    return {
      'sessionsLoggedThisWeek': sessionsLoggedThisWeek,
      'avgSessionDurationMinutes': avgSessionDurationMinutes,
      'recoveryScore': recoveryScore,
      'primaryFocusArea': primaryFocusArea,
      'confidence': confidence.name,
    }..removeWhere((key, value) => value == null);
  }
}
