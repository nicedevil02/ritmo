import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  group('CAL-18: Dead Agenda Date Range Removal & Constants', () {
    test('calculateDateRangeForScale with JourneyScale.agenda throws StateError', () {
      expect(
        () => JourneyController.calculateDateRangeForScale(JourneyScale.agenda, DateTime.now()),
        throwsStateError,
        reason: 'Agenda scale must use loadAgendaRange and throw StateError in date range helper',
      );
    });

    test('agendaWindowDays constants are 14 back and 45 forward', () {
      expect(JourneyController.agendaWindowDaysBack, equals(14));
      expect(JourneyController.agendaWindowDaysForward, equals(45));
    });

    test('calculateDateRangeForScale handles day, week, month, and year correctly', () {
      final testDate = DateTime(2026, 8, 18);
      final testDateOnly = DateKey.dayOf(testDate);

      // Day scale
      final dayRange = JourneyController.calculateDateRangeForScale(JourneyScale.day, testDate);
      expect(dayRange.start, equals(testDateOnly));
      expect(dayRange.end, equals(testDateOnly));

      // Week scale
      final weekRange = JourneyController.calculateDateRangeForScale(JourneyScale.week, testDate);
      expect(weekRange.end.difference(weekRange.start).inDays, equals(6));

      // Month scale
      final j = Jalali.fromDateTime(testDateOnly);
      final monthRange = JourneyController.calculateDateRangeForScale(JourneyScale.month, testDate);
      expect(Jalali.fromDateTime(monthRange.start).day, equals(1));
      expect(Jalali.fromDateTime(monthRange.end).day, equals(Jalali(j.year, j.month, 1).monthLength));

      // Year scale
      final yearRange = JourneyController.calculateDateRangeForScale(JourneyScale.year, testDate);
      expect(Jalali.fromDateTime(yearRange.start).month, equals(1));
      expect(Jalali.fromDateTime(yearRange.start).day, equals(1));
      expect(Jalali.fromDateTime(yearRange.end).month, equals(12));
    });
  });
}
