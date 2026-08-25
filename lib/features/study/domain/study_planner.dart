import 'dart:math' as math;
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/features/study/domain/study_models.dart';

class StudyRecommendation {
  const StudyRecommendation({
    required this.subject,
    required this.topic,
    required this.suggestedMinutes,
    required this.reason,
    required this.score,
  });

  final StudySubject subject;
  final StudyTopic topic;
  final int suggestedMinutes;
  final String reason;
  final int score;
}

class StudyPlanner {
  const StudyPlanner._();

  static List<StudyRecommendation> evaluate({
    required List<StudySubject> subjects,
    required List<StudyTopic> topics,
    required List<StudySession> todaySessions,
    required DateTime today,
    int dailyCapacityMinutes = 90,
    bool reviewEnabled = true,
  }) {
    if (subjects.isEmpty || topics.isEmpty) return [];

    final todayStr = RitmoDate.dayKey(today);
    final todayStart = RitmoDate.startOfDay(today);
    final subjectMap = {for (final s in subjects) s.id: s};
    final todayStudiedTopicIds = todaySessions.map((s) => s.topicId).whereType<String>().toSet();

    final todayStudiedMinutes = todaySessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final remainingCap = dailyCapacityMinutes - todayStudiedMinutes;
    final suggestedMin = remainingCap >= 15 ? math.min(30, remainingCap) : (remainingCap > 0 ? remainingCap : 30);

    final recs = <StudyRecommendation>[];

    for (final topic in topics) {
      final subject = subjectMap[topic.subjectId];
      if (subject == null || subject.isArchived) continue;

      // Rule 0: Mastered topics that are NOT due for review should not clutter recommendations
      final isReviewDue = reviewEnabled && topic.nextReviewDateIso != null && topic.nextReviewDateIso!.compareTo(todayStr) <= 0;
      if (topic.mastery == StudyMastery.mastered && !isReviewDue) {
        continue;
      }

      int score = 0;
      String winnerReason = 'پیشنهاد برنامه‌ریزی';
      int maxRulePoints = -999;

      // Rule 1: Review due (+40)
      if (isReviewDue) {
        score += 40;
        if (40 > maxRulePoints) {
          maxRulePoints = 40;
          winnerReason = 'امروز موعد مرور این مبحث است';
        }
      }

      // Rule 2: Unstudied (never studied) (+30) vs >7 days unstudied (+25)
      if (topic.lastStudiedAtMs == null) {
        score += 30;
        if (30 > maxRulePoints) {
          maxRulePoints = 30;
          winnerReason = 'هنوز مطالعه این سرفصل را شروع نکرده‌اید';
        }
      } else {
        final lastStudiedDt = DateTime.fromMillisecondsSinceEpoch(topic.lastStudiedAtMs!);
        final daysDiff = todayStart.difference(RitmoDate.startOfDay(lastStudiedDt)).inDays;
        if (daysDiff >= 7) {
          score += 25;
          if (25 > maxRulePoints) {
            maxRulePoints = 25;
            winnerReason = '$daysDiff روزه سراغ «${topic.name}» نرفتی';
          }
        }
      }

      // Rule 3: Learning status (+20)
      if (topic.mastery == StudyMastery.learning) {
        score += 20;
        if (20 > maxRulePoints) {
          maxRulePoints = 20;
          winnerReason = 'در حال یادگیری — نیاز به تکمیل مبحث';
        }
      }

      // Rule 4: Planned date (+15)
      if (topic.plannedDateIso == todayStr) {
        score += 15;
        if (15 > maxRulePoints) {
          maxRulePoints = 15;
          winnerReason = 'خودت برای امروز برنامه‌ریزیش کردی';
        }
      }

      // Rule 5: Fits in capacity (+10)
      if (remainingCap >= 25) {
        score += 10;
        if (10 > maxRulePoints) {
          maxRulePoints = 10;
          winnerReason = 'تو وقت امروزت جا می‌شه';
        }
      }

      // Rule 6: Studied today (-30)
      if (todayStudiedTopicIds.contains(topic.id)) {
        score -= 30;
      }

      recs.add(StudyRecommendation(
        subject: subject,
        topic: topic,
        suggestedMinutes: suggestedMin,
        reason: winnerReason,
        score: score,
      ));
    }

    recs.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return a.topic.orderIndex.compareTo(b.topic.orderIndex);
    });

    return recs;
  }
}
