import 'package:ritmo/features/goals/models/planning_models.dart';

class ScoreBreakdown {
  const ScoreBreakdown({
    required this.deadlineUrgency,
    required this.goalPaceGap,
    required this.ageWithoutProgress,
    required this.continuityBonus,
    required this.userPreference,
    required this.total,
  });

  final double deadlineUrgency;
  final double goalPaceGap;
  final double ageWithoutProgress;
  final double continuityBonus;
  final double userPreference;
  final double total;

  String toReasonFa() {
    final parts = <String>[];
    if (deadlineUrgency >= 20) parts.add('مهلتش نزدیک است');
    if (goalPaceGap >= 15) parts.add('هدفش از زمان عقب است');
    if (ageWithoutProgress >= 10) parts.add('مدتی است بی‌توجه مانده');
    if (continuityBonus >= 5) parts.add('دیروز هم رویش کار کردی');
    if (userPreference > 0) parts.add('در اولویت‌های تو بود');
    return parts.isEmpty ? 'اولویت عادی' : parts.join('، ');
  }
}

class CommitmentScorer {
  const CommitmentScorer();

  ScoreBreakdown score({
    required PlanningCommitment c,
    required String todayKey,
    int? daysToDeadline,
    double? goalPaceGap01, // درصد زمان گذشته منهای درصد پیشرفت، 0..1
    int? daysSinceLastProgress,
    bool workedOnYesterday = false,
    bool inUserPriorities = false,
  }) {
    double urgency = 0;
    if (daysToDeadline != null) {
      if (daysToDeadline <= 2) {
        urgency = 40;
      } else if (daysToDeadline <= 5) {
        urgency = 25;
      } else if (daysToDeadline <= 10) {
        urgency = 12;
      }
    }
    final pace = ((goalPaceGap01 ?? 0).clamp(0.0, 1.0)) * 30;
    var age = 0.0;
    final d = daysSinceLastProgress;
    if (d != null) {
      if (d >= 14) {
        age = 20;
      } else if (d >= 7) {
        age = 12;
      } else if (d >= 4) {
        age = 6;
      }
    }
    final continuity = workedOnYesterday ? 8.0 : 0.0;
    final pref = inUserPriorities ? 10.0 : 0.0;
    return ScoreBreakdown(
      deadlineUrgency: urgency,
      goalPaceGap: pace,
      ageWithoutProgress: age,
      continuityBonus: continuity,
      userPreference: pref,
      total: urgency + pace + age + continuity + pref,
    );
  }
}
