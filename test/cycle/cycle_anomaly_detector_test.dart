import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/features/cycle/logic/cycle_anomaly_detector.dart';

void main() {
  group('CycleAnomalyDetector Tests (C-32)', () {
    test(
      'C-32: 40-day overdue period produces lateOrMissedPeriod anomaly with consultClinician severity',
      () {
        final engineOutput = CycleEngineOutput(
          hasData: true,
          currentPhase: CyclePhase.dataStale,
          dayOfCycle: 68,
          dayOfPeriod: 0,
          daysOverdue: 40,
          missedCycles: 2,
          isOverdue: true,
          isIrregular: false,
          dataMaturity: 'LOW',
          trendPoints: const [],
          stats: CycleStats(
            avgCycleLength: 28,
            avgPeriodDuration: 6,
            recordedPeriods: 2,
            completedCycles: 1,
          ),
        );

        final periodRows = [
          {'id': 'p1', 'startDate': '2026-05-01', 'endDate': '2026-05-06'},
          {'id': 'p2', 'startDate': '2026-05-29', 'endDate': '2026-06-03'},
        ];

        final anomalies = CycleAnomalyDetector.detectAnomalies(
          periodRows: periodRows,
          avgCycleLength: 28,
          engineOutput: engineOutput,
        );

        expect(
          anomalies.any((a) => a.type == CycleAnomalyType.lateOrMissedPeriod),
          isTrue,
        );
        final lateAnomaly = anomalies.firstWhere(
          (a) => a.type == CycleAnomalyType.lateOrMissedPeriod,
        );
        expect(
          lateAnomaly.severity,
          equals(CycleAnomalySeverity.consultClinician),
        );
        expect(lateAnomaly.isMild, isFalse);
      },
    );

    test('C-32: Abnormally short cycle (< 21 days) is detected', () {
      final periodRows = [
        {'id': 'p1', 'startDate': '2026-06-01', 'endDate': '2026-06-06'},
        {
          'id': 'p2',
          'startDate': '2026-06-19',
          'endDate': '2026-06-24',
        }, // 18 days cycle
      ];

      final anomalies = CycleAnomalyDetector.detectAnomalies(
        periodRows: periodRows,
        avgCycleLength: 28,
      );

      expect(
        anomalies.any((a) => a.type == CycleAnomalyType.abnormallyShortCycle),
        isTrue,
      );
      final shortAnomaly = anomalies.firstWhere(
        (a) => a.type == CycleAnomalyType.abnormallyShortCycle,
      );
      expect(
        shortAnomaly.severity,
        equals(CycleAnomalySeverity.consultClinician),
      );
    });

    test(
      'C-32: Leave-one-out reference baseline correctly compares against historical cycles',
      () {
        final periodRows = [
          {'id': 'p1', 'startDate': '2026-03-01', 'endDate': '2026-03-06'},
          {
            'id': 'p2',
            'startDate': '2026-03-29',
            'endDate': '2026-04-03',
          }, // Cycle 1: 28 days
          {
            'id': 'p3',
            'startDate': '2026-04-26',
            'endDate': '2026-05-01',
          }, // Cycle 2: 28 days
          {
            'id': 'p4',
            'startDate': '2026-06-10',
            'endDate': '2026-06-15',
          }, // Cycle 3: 45 days (abnormal)
        ];

        final anomalies = CycleAnomalyDetector.detectAnomalies(
          periodRows: periodRows,
          avgCycleLength: 28,
        );

        expect(
          anomalies.any((a) => a.type == CycleAnomalyType.abnormallyLongCycle),
          isTrue,
        );
        final longAnomaly = anomalies.firstWhere(
          (a) => a.type == CycleAnomalyType.abnormallyLongCycle,
        );
        expect(
          longAnomaly.descriptionFa.contains('28 روز'),
          isTrue,
        ); // Reference avg of previous cycles is 28
      },
    );
  });
}
