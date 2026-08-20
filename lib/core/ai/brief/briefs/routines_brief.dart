import 'package:ritmo/core/ai/brief/domain_brief.dart';

class RoutinesBrief implements DomainBrief {
  const RoutinesBrief({
    required this.sampleSize,
    required this.computedAt,
    required this.activeRoutinesCount,
    required this.weeklyAdherencePercentage,
    required this.longestStreak,
    required this.remainingTodayCount,
  });

  @override
  final String domainId = 'routines';

  @override
  final int sampleSize;

  @override
  final DateTime computedAt;

  final int activeRoutinesCount;
  final double weeklyAdherencePercentage;
  final int longestStreak;
  final int remainingTodayCount;

  @override
  BriefConfidence get confidence {
    if (sampleSize < 1) return BriefConfidence.none;
    if (sampleSize < 3) return BriefConfidence.low;
    if (sampleSize < 7) return BriefConfidence.medium;
    return BriefConfidence.high;
  }

  @override
  List<String> get fieldNames => const [
        'routines.activeRoutinesCount',
        'routines.weeklyAdherencePercentage',
        'routines.longestStreak',
        'routines.remainingTodayCount',
      ];

  @override
  Map<String, Object?> toPromptJson() {
    return {
      'activeRoutinesCount': activeRoutinesCount,
      'weeklyAdherencePercentage': weeklyAdherencePercentage,
      'longestStreak': longestStreak,
      'remainingTodayCount': remainingTodayCount,
      'confidence': confidence.name,
    };
  }
}
