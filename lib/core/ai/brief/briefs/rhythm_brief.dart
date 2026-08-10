import 'package:ritmo/core/ai/brief/domain_brief.dart';

class RhythmBrief implements DomainBrief {
  RhythmBrief({
    required this.sampleSize,
    required this.computedAt,
    required this.dailyCapacityMinutes,
    required this.allocatedMinutes,
    required this.activeDomainCount,
    this.topOverdueItem,
  });

  @override
  final String domainId = 'rhythm';

  @override
  final int sampleSize;

  @override
  final DateTime computedAt;

  final int dailyCapacityMinutes;
  final int allocatedMinutes;
  final int activeDomainCount;
  final String? topOverdueItem;

  @override
  BriefConfidence get confidence {
    if (sampleSize < 1) return BriefConfidence.none;
    if (sampleSize < 3) return BriefConfidence.low;
    if (sampleSize < 7) return BriefConfidence.medium;
    return BriefConfidence.high;
  }

  @override
  List<String> get fieldNames => [
        'rhythm.dailyCapacityMinutes',
        'rhythm.allocatedMinutes',
        'rhythm.activeDomainCount',
        'rhythm.topOverdueItem',
      ];

  @override
  Map<String, Object?> toPromptJson() {
    return {
      'dailyCapacityMinutes': dailyCapacityMinutes,
      'allocatedMinutes': allocatedMinutes,
      'activeDomainCount': activeDomainCount,
      'topOverdueItem': topOverdueItem,
      'confidence': confidence.name,
    }..removeWhere((key, value) => value == null);
  }
}
