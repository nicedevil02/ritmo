import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/models/cycle_forecast_models.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_calendar_grid.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../support/responsive_harness.dart';

void main() {
  group('R-32 / R-44: CycleCalendarGrid 6-row worst case resilience', () {
    testWidgets('CycleCalendarGrid fits 6-row 31-day month without overflow on 320x568 at 1.6x scale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Jalali(1403, 5, 1) starts on Thursday (weekDay = 6), length = 31 days (Mordad 1403)
      // This forces 6 full rows in 7-column grid!
      final cal = Jalali(1403, 5, 1);
      final marks = <String, CycleDayMark>{
        '1403-05-01': const CycleDayMark(kind: CycleDayKind.recordedPeriod),
        '1403-05-14': const CycleDayMark(kind: CycleDayKind.ovulation),
        '1403-05-28': const CycleDayMark(kind: CycleDayKind.predictedPeriod, confidenceLevel: PredictionConfidenceLevel.high),
      };

      await tester.pumpWidget(
        wrapResponsive(
          Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CycleCalendarGrid(
                  cal: cal,
                  marks: marks,
                  selectedDay: DateTime(2024, 7, 22),
                  activePhaseColor: Colors.purple,
                ),
              ),
            ),
          ),
          size: const Size(320, 568),
          textScale: 1.6,
        ),
      );

      await expectNoOverflow(tester, label: 'CycleCalendarGrid 6-row Mordad 1403 @ 320x568 1.6x');
    });
  });
}
