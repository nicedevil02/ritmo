import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';

void main() {
  group('WorshipPracticeState Date Isolation Tests', () {
    test('1. dailyDone on 2026-08-10 does NOT leak to 2026-08-11', () {
      final practice = WorshipPractice(
        id: 'wp_fajr',
        practiceType: 'PRAYER',
        subType: 'FAJR',
        title: 'نماز صبح',
        createdAt: 0,
        updatedAt: 0,
        dailyDone: 1,
        dailyDoneDate: '2026-08-10',
      );

      final futureState = WorshipPracticeState(
        practice: practice,
        dateStr: '2026-08-11',
        countDone: 0,
        countTarget: 1,
        resultType: null,
      );

      expect(futureState.isDone, isFalse);
      expect(futureState.isPending, isTrue);
    });

    test('2. dailyDone on 2026-08-10 applies correctly to 2026-08-10', () {
      final practice = WorshipPractice(
        id: 'wp_fajr',
        practiceType: 'PRAYER',
        subType: 'FAJR',
        title: 'نماز صبح',
        createdAt: 0,
        updatedAt: 0,
        dailyDone: 1,
        dailyDoneDate: '2026-08-10',
      );

      final sameDayState = WorshipPracticeState(
        practice: practice,
        dateStr: '2026-08-10',
        countDone: 0,
        countTarget: 1,
        resultType: null,
      );

      expect(sameDayState.isDone, isTrue);
    });

    test('3. resultType == DONE gives isDone == true regardless of dailyDone', () {
      final practice = WorshipPractice(
        id: 'wp_fajr',
        practiceType: 'PRAYER',
        subType: 'FAJR',
        title: 'نماز صبح',
        createdAt: 0,
        updatedAt: 0,
        dailyDone: 0,
        dailyDoneDate: null,
      );

      final state = WorshipPracticeState(
        practice: practice,
        dateStr: '2026-08-15',
        countDone: 1,
        countTarget: 1,
        resultType: 'DONE',
      );

      expect(state.isDone, isTrue);
    });

    test('4. dailyDone = -1 (skipped) on 2026-08-10 does NOT leak to 2026-08-12', () {
      final practice = WorshipPractice(
        id: 'wp_dhuhr',
        practiceType: 'PRAYER',
        subType: 'DHUHR',
        title: 'نماز ظهر',
        createdAt: 0,
        updatedAt: 0,
        dailyDone: -1,
        dailyDoneDate: '2026-08-10',
      );

      final futureState = WorshipPracticeState(
        practice: practice,
        dateStr: '2026-08-12',
        countDone: 0,
        countTarget: 1,
        resultType: null,
      );

      expect(futureState.isSkipped, isFalse);
      expect(futureState.isPending, isTrue);
    });

    test('5. resultType == null with countDone = 0 and countTarget = 1 is NOT done', () {
      final practice = WorshipPractice(
        id: 'wp_asr',
        practiceType: 'PRAYER',
        subType: 'ASR',
        title: 'نماز عصر',
        createdAt: 0,
        updatedAt: 0,
        dailyDone: 0,
        dailyDoneDate: null,
      );

      final state = WorshipPracticeState(
        practice: practice,
        dateStr: '2026-08-10',
        countDone: 0,
        countTarget: 1,
        resultType: null,
      );

      expect(state.isDone, isFalse);
      expect(state.isPending, isTrue);
    });
  });
}
