// F-25..F-34: CycleCalendarView & MonthMarks Tests
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/models/cycle_forecast_models.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_calendar_view.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  group('CycleCalendarView.buildMonthMarks Pure Computation Tests (F-25..F-34)', () {
    test('F-25: builds accurate marks for recorded period and forecast days', () {
      // Month: Mordad 1405 (approx July 23 to August 22, 2026)
      final month = Jalali(1405, 5, 1);

      final periods = [
        {
          'id': 1,
          'startDate': '2026-07-24', // 1405/5/2
          'endDate': '2026-07-29', // 1405/5/7
        }
      ];

      final forecast = [
        PredictedCycle(
          index: 1,
          predictedStart: DateTime(2026, 8, 15),
          predictedEnd: DateTime(2026, 8, 20),
          windowStart: DateTime(2026, 8, 13),
          windowEnd: DateTime(2026, 8, 22),
          sigmaDays: 2.0,
          periodDays: 6,
          confidence: 0.85,
          confidenceLevel: PredictionConfidenceLevel.high,
          basis: ForecastBasis.measured,
          ovulationDay: DateTime(2026, 8, 5),
          fertileStart: DateTime(2026, 8, 1),
          fertileEnd: DateTime(2026, 8, 6),
          pmsStart: DateTime(2026, 8, 11),
          pmsEnd: DateTime(2026, 8, 14),
        ),
      ];

      final loggedDayKeys = {'2026-07-24', '2026-08-05'};

      final marks = CycleCalendarView.buildMonthMarks(
        month: month,
        periods: periods,
        loggedDayKeys: loggedDayKeys,
        forecast: forecast,
        defaultPeriodDuration: 6,
      );

      expect(marks.isNotEmpty, isTrue);
      expect(marks.length, month.monthLength);

      // Recorded period day check
      final recMark = marks['2026-07-24'];
      expect(recMark, isNotNull);
      expect(recMark!.kind, equals(CycleDayKind.recordedPeriod));
      expect(recMark.hasLog, isTrue);

      // Predicted period day check
      final predMark = marks['2026-08-16'];
      expect(predMark, isNotNull);
      expect(predMark!.kind, equals(CycleDayKind.predictedPeriod));
      expect(predMark.confidenceLevel, equals(PredictionConfidenceLevel.high));

      // Prediction window shift day check (Aug 21 is inside window but outside predicted period)
      final winMark = marks['2026-08-21'];
      expect(winMark, isNotNull);
      expect(winMark!.kind, equals(CycleDayKind.predictionWindow));

      // Ovulation day check
      final ovMark = marks['2026-08-05'];
      expect(ovMark, isNotNull);
      expect(ovMark!.kind, equals(CycleDayKind.ovulation));
      expect(ovMark.hasLog, isTrue);

      // Fertile day check (Aug 2)
      final fertMark = marks['2026-08-02'];
      expect(fertMark, isNotNull);
      expect(fertMark!.kind, equals(CycleDayKind.fertileWindow));

      // PMS day check (Aug 12)
      final pmsMark = marks['2026-08-12'];
      expect(pmsMark, isNotNull);
      expect(pmsMark!.kind, equals(CycleDayKind.pms));
    });

    test('F-28: safely handles invalid or null period date strings without throwing', () {
      final month = Jalali(1405, 5, 1);
      final malformedPeriods = [
        {'id': 1, 'startDate': null, 'endDate': 'invalid-date'},
        {'id': 2, 'startDate': 'bad_string', 'endDate': null},
        {'id': 3, 'startDate': '2026-07-25', 'endDate': null},
      ];

      final marks = CycleCalendarView.buildMonthMarks(
        month: month,
        periods: malformedPeriods,
        loggedDayKeys: {},
        forecast: [],
        defaultPeriodDuration: 6,
      );

      expect(marks.length, month.monthLength);
      expect(marks['2026-07-25']?.kind, equals(CycleDayKind.recordedPeriod));
    });
  });
}
