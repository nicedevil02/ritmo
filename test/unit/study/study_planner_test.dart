import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/study/domain/study_models.dart';
import 'package:ritmo/features/study/domain/study_planner.dart';

void main() {
  group('StudyPlanner Unit Tests', () {
    final now = DateTime(2026, 8, 7);
    const todayStr = '2026-08-07';

    const subject = StudySubject(id: 's1', name: 'ریاضی');

    test('Topic due for review takes precedence over unstudied topic', () {
      const topic1 = StudyTopic(
        id: 't1',
        subjectId: 's1',
        name: 'مشتّق',
        mastery: StudyMastery.learning,
        orderIndex: 1,
      );

      const topic2 = StudyTopic(
        id: 't2',
        subjectId: 's1',
        name: 'حد',
        mastery: StudyMastery.review,
        nextReviewDateIso: todayStr,
        orderIndex: 2,
      );

      final recs = StudyPlanner.evaluate(
        subjects: [subject],
        topics: [topic1, topic2],
        todaySessions: [],
        today: now,
      );

      expect(recs.first.topic.id, equals('t2'));
      expect(recs.first.reason, contains('مرور'));
    });

    test('reviewEnabled=false ignores review date', () {
      const topic1 = StudyTopic(
        id: 't1',
        subjectId: 's1',
        name: 'مشتّق',
        mastery: StudyMastery.learning,
        orderIndex: 1,
      );

      const topic2 = StudyTopic(
        id: 't2',
        subjectId: 's1',
        name: 'حد',
        mastery: StudyMastery.mastered,
        nextReviewDateIso: todayStr,
        orderIndex: 2,
      );

      final recs = StudyPlanner.evaluate(
        subjects: [subject],
        topics: [topic1, topic2],
        todaySessions: [],
        today: now,
        reviewEnabled: false,
      );

      expect(recs.first.topic.id, equals('t1'));
    });

    test('Studied topic today is penalized', () {
      const topic1 = StudyTopic(id: 't1', subjectId: 's1', name: 'مشتّق');
      const topic2 = StudyTopic(id: 't2', subjectId: 's1', name: 'حد');

      const todaySession = StudySession(
        id: 'sess1',
        subjectId: 's1',
        topicId: 't1',
        durationMinutes: 30,
        dateIso: todayStr,
        createdAtMs: 0,
      );

      final recs = StudyPlanner.evaluate(
        subjects: [subject],
        topics: [topic1, topic2],
        todaySessions: [todaySession],
        today: now,
      );

      expect(recs.first.topic.id, equals('t2'));
    });
  });
}
