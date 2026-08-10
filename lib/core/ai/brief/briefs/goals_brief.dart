import 'package:ritmo/core/ai/brief/domain_brief.dart';

class GoalsBrief implements DomainBrief {
  GoalsBrief({
    required this.sampleSize,
    required this.computedAt,
    required this.activeGoalsCount,
    required this.overallProgressPercentage,
    required this.overdueStepsCount,
    required this.deadGoalsCount,
  });

  @override
  final String domainId = 'goals';

  @override
  final int sampleSize;

  @override
  final DateTime computedAt;

  final int activeGoalsCount;
  final double overallProgressPercentage;
  final int overdueStepsCount;
  final int deadGoalsCount;

  @override
  BriefConfidence get confidence {
    if (sampleSize < 1) return BriefConfidence.none;
    if (sampleSize < 3) return BriefConfidence.low;
    if (sampleSize < 7) return BriefConfidence.medium;
    return BriefConfidence.high;
  }

  @override
  List<String> get fieldNames => [
        'goals.activeGoalsCount',
        'goals.overallProgressPercentage',
        'goals.overdueStepsCount',
        'goals.deadGoalsCount',
      ];

  @override
  Map<String, Object?> toPromptJson() {
    return {
      'activeGoalsCount': activeGoalsCount,
      'overallProgressPercentage': overallProgressPercentage,
      'overdueStepsCount': overdueStepsCount,
      'deadGoalsCount': deadGoalsCount,
      'confidence': confidence.name,
    };
  }
}
