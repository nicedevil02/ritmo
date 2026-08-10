import 'package:ritmo/core/ai/brief/domain_brief.dart';

class StudyBrief implements DomainBrief {
  StudyBrief({
    required this.sampleSize,
    required this.computedAt,
    required this.activeSubjectsCount,
    this.topPrioritySubject,
    this.avgWeeklyStudyHours,
    this.recentMockExamAvg,
  });

  @override
  final String domainId = 'konkur';

  @override
  final int sampleSize;

  @override
  final DateTime computedAt;

  final int activeSubjectsCount;
  final String? topPrioritySubject;
  final double? avgWeeklyStudyHours;
  final double? recentMockExamAvg;

  @override
  BriefConfidence get confidence {
    if (sampleSize < 1) return BriefConfidence.none;
    if (sampleSize < 3) return BriefConfidence.low;
    if (sampleSize < 7) return BriefConfidence.medium;
    return BriefConfidence.high;
  }

  @override
  List<String> get fieldNames => [
        'konkur.activeSubjectsCount',
        'konkur.topPrioritySubject',
        'konkur.avgWeeklyStudyHours',
        'konkur.recentMockExamAvg',
      ];

  @override
  Map<String, Object?> toPromptJson() {
    return {
      'activeSubjectsCount': activeSubjectsCount,
      'topPrioritySubject': topPrioritySubject,
      'avgWeeklyStudyHours': avgWeeklyStudyHours,
      'recentMockExamAvg': recentMockExamAvg,
      'confidence': confidence.name,
    }..removeWhere((key, value) => value == null);
  }
}
