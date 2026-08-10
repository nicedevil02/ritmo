import 'package:ritmo/core/ai/brief/domain_brief.dart';

class WellbeingBrief implements DomainBrief {
  WellbeingBrief({
    required this.sampleSize,
    required this.computedAt,
    this.wellbeingScore,
    this.energyLevelAvg,
    this.recentMood,
    this.stressLevel,
    this.primaryStressor,
  });

  @override
  final String domainId = 'wellbeing';

  @override
  final int sampleSize;

  @override
  final DateTime computedAt;

  final double? wellbeingScore;
  final double? energyLevelAvg;
  final String? recentMood;
  final double? stressLevel;
  final String? primaryStressor;

  @override
  BriefConfidence get confidence {
    if (sampleSize < 2) return BriefConfidence.none;
    if (sampleSize < 5) return BriefConfidence.low;
    if (sampleSize < 14) return BriefConfidence.medium;
    return BriefConfidence.high;
  }

  @override
  List<String> get fieldNames => [
        'wellbeing.wellbeingScore',
        'wellbeing.energyLevelAvg',
        'wellbeing.recentMood',
        'wellbeing.stressLevel',
        'wellbeing.primaryStressor',
      ];

  @override
  Map<String, Object?> toPromptJson() {
    return {
      'wellbeingScore': wellbeingScore,
      'energyLevelAvg': energyLevelAvg,
      'recentMood': recentMood,
      'stressLevel': stressLevel,
      'primaryStressor': primaryStressor,
      'confidence': confidence.name,
    }..removeWhere((key, value) => value == null);
  }
}
