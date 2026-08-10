import 'package:ritmo/core/ai/brief/domain_brief.dart';

class ReflectionBrief implements DomainBrief {
  ReflectionBrief({
    required this.sampleSize,
    required this.computedAt,
    required this.totalReflections,
    this.frequentKeywords = const [],
    this.topWin,
    this.topLearning,
  });

  @override
  final String domainId = 'reflection';

  @override
  final int sampleSize;

  @override
  final DateTime computedAt;

  final int totalReflections;
  final List<String> frequentKeywords;
  final String? topWin;
  final String? topLearning;

  @override
  BriefConfidence get confidence {
    if (sampleSize < 1) return BriefConfidence.none;
    if (sampleSize < 3) return BriefConfidence.low;
    if (sampleSize < 7) return BriefConfidence.medium;
    return BriefConfidence.high;
  }

  @override
  List<String> get fieldNames => [
        'reflection.totalReflections',
        'reflection.frequentKeywords',
        'reflection.topWin',
        'reflection.topLearning',
      ];

  @override
  Map<String, Object?> toPromptJson() {
    return {
      'totalReflections': totalReflections,
      'frequentKeywords': frequentKeywords,
      'topWin': topWin,
      'topLearning': topLearning,
      'confidence': confidence.name,
    }..removeWhere((key, value) => value == null);
  }
}
