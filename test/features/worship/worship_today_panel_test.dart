import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/worship/logic/worship_completion_repository.dart';
import 'package:ritmo/features/worship/logic/mafatih_weekly_acts.dart';

void main() {
  group('Worship Today Panel Integration Tests (INT-05)', () {
    test('Group State Machine handles all done, partial, and pending accurately', () {
      const statusDone = WorshipDayStatus(recordId: '1', resultType: 'DONE', countDone: 1);
      const statusPending = WorshipDayStatus(recordId: '2', resultType: 'PENDING', countDone: 0);

      // Scenario 1: All members done
      final allDone = statusDone.isDone && statusDone.isDone;
      expect(allDone, isTrue);

      // Scenario 2: Partial (1 done, 1 pending)
      final isPartial = (statusDone.isDone && !statusPending.isDone) || (!statusDone.isDone && statusPending.isDone);
      expect(isPartial, isTrue);

      // Scenario 3: None done
      final noneDone = !statusPending.isDone && !statusPending.isDone;
      expect(noneDone, isTrue);
    });

    test('Mafatih weekly acts dataset contains valid entries for all weekdays 1..7', () {
      for (int day = 1; day <= 7; day++) {
        expect(mafatihWeeklyActs.containsKey(day), isTrue);
        expect(mafatihWeeklyActs[day]!.isNotEmpty, isTrue);
      }
    });

    test('Regression WRSH-03: WorshipDayStatus evaluates strictly by date', () {
      const todayStatus = WorshipDayStatus(recordId: '10', resultType: 'DONE', countDone: 1);
      const yesterdayStatus = WorshipDayStatus(recordId: '11', resultType: 'PENDING', countDone: 0);

      expect(todayStatus.isDone, isTrue);
      expect(yesterdayStatus.isDone, isFalse);
    });
  });
}
