import 'package:ritmo/core/ai/brief/domain_brief.dart';

class CoursesBrief implements DomainBrief {
  CoursesBrief({
    required this.sampleSize,
    required this.computedAt,
    required this.activeCoursesCount,
    required this.weeklyTargetSessions,
    required this.completedSessionsThisWeek,
    this.estimatedCompletionEtaDays,
  });

  @override
  final String domainId = 'courses';

  @override
  final int sampleSize;

  @override
  final DateTime computedAt;

  final int activeCoursesCount;
  final int weeklyTargetSessions;
  final int completedSessionsThisWeek;
  final int? estimatedCompletionEtaDays;

  @override
  BriefConfidence get confidence {
    if (sampleSize < 1) return BriefConfidence.none;
    if (sampleSize < 3) return BriefConfidence.low;
    if (sampleSize < 7) return BriefConfidence.medium;
    return BriefConfidence.high;
  }

  @override
  List<String> get fieldNames => [
        'courses.activeCoursesCount',
        'courses.weeklyTargetSessions',
        'courses.completedSessionsThisWeek',
        'courses.estimatedCompletionEtaDays',
      ];

  @override
  Map<String, Object?> toPromptJson() {
    return {
      'activeCoursesCount': activeCoursesCount,
      'weeklyTargetSessions': weeklyTargetSessions,
      'completedSessionsThisWeek': completedSessionsThisWeek,
      'estimatedCompletionEtaDays': estimatedCompletionEtaDays,
      'confidence': confidence.name,
    }..removeWhere((key, value) => value == null);
  }
}
