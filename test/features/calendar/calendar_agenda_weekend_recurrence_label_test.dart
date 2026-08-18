import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/calendar/presentation/logic/agenda_bucketing.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-33: Fix Meaningless Weekend Recurrence Label in Agenda', () {
    test('calculateDaysInBucket for thisWeek on Thursday and Friday returns 0', () {
      // 1405-05-29 is Thursday, 1405-05-30 is Friday (Shamsi)
      final thursdayJalali = Jalali(1405, 5, 29);
      final fridayJalali = Jalali(1405, 5, 30);

      final thursday = thursdayJalali.toDateTime();
      final friday = fridayJalali.toDateTime();

      final daysThu = calculateDaysInBucket(AgendaBucket.thisWeek, now: thursday, items: []);
      final daysFri = calculateDaysInBucket(AgendaBucket.thisWeek, now: friday, items: []);

      expect(daysThu, equals(0), reason: 'On Thursday, thisWeek bucket has 0 days remaining');
      expect(daysFri, equals(0), reason: 'On Friday, thisWeek bucket has 0 days remaining');
    });

    test('calculateRecurrenceLabel does not produce invalid "X روز از ۱" when daysInBucket is 0', () {
      final dates = [
        DateTime(2026, 8, 20),
        DateTime(2026, 8, 21),
        DateTime(2026, 8, 22),
      ];

      final label = calculateRecurrenceLabel(dates, 0);

      expect(label.contains('از ۱'), isFalse);
      expect(label.contains('از 1'), isFalse);
      expect(label, equals('هر روز'), reason: '3 dates with fallback m=3 means every day');
    });

    test('calculateRecurrenceLabel handles n == m as "هر روز" even for 2 days', () {
      final dates = [
        DateTime(2026, 8, 20),
        DateTime(2026, 8, 21),
      ];

      final label = calculateRecurrenceLabel(dates, 2);
      expect(label, equals('هر روز'));
    });
  });
}
