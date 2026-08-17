// CycleAnomalyDetector (C-32, C-41: Statistical anomalies & code-based contract)
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';

enum CycleAnomalyType {
  lateOrMissedPeriod,
  abnormallyShortCycle,
  abnormallyLongCycle,
  unusuallyLongBleeding,
  unusuallyHeavyFlowStreak,
  highVariabilityTrend,
}

enum CycleAnomalySeverity { info, watch, consultClinician }

class CycleAnomaly {
  const CycleAnomaly({
    required this.type,
    required this.severity,
    this.paramValue = 0,
    this.referenceValue = 0,
    this.isMild = true,
    String? titleFa,
    String? descriptionFa,
  })  : _titleFa = titleFa,
        _descriptionFa = descriptionFa;

  final CycleAnomalyType type;
  final CycleAnomalySeverity severity;
  final int paramValue;
  final int referenceValue;
  final bool isMild;
  final String? _titleFa;
  final String? _descriptionFa;

  String get titleFa => _titleFa ?? type.name;
  String get descriptionFa => _descriptionFa ?? type.name;
}

class CycleAnomalyDetector {
  static List<CycleAnomaly> detectAnomalies({
    required List<Map<String, dynamic>> periodRows,
    required double avgCycleLength,
    CycleEngineOutput? engineOutput,
    DateTime? now,
  }) {
    final anomalies = <CycleAnomaly>[];

    // 1. Check for Late or Missed Period
    if (engineOutput != null) {
      if (engineOutput.daysOverdue >= 7 || engineOutput.missedCycles >= 1) {
        final isSevere =
            engineOutput.daysOverdue >= 30 || engineOutput.missedCycles >= 2;
        anomalies.add(
          CycleAnomaly(
            type: CycleAnomalyType.lateOrMissedPeriod,
            severity: isSevere
                ? CycleAnomalySeverity.consultClinician
                : CycleAnomalySeverity.watch,
            paramValue: engineOutput.daysOverdue,
            referenceValue: engineOutput.missedCycles,
            isMild: !isSevere,
          ),
        );
      }
    }

    if (periodRows.length < 2) return anomalies;

    // Sort periods chronologically ascending
    final sorted = [...periodRows]
      ..sort((a, b) {
        final aStart = a['startDate']?.toString() ?? '';
        final bStart = b['startDate']?.toString() ?? '';
        return aStart.compareTo(bStart);
      });

    // 2. Extract cycle lengths
    final cycleLengths = <int>[];
    final periodDurations = <int>[];

    for (var i = 0; i < sorted.length; i++) {
      final start = CycleDateContract.parseDayKey(
        sorted[i]['startDate']?.toString(),
      );
      if (start == null) continue;

      final end = CycleDateContract.parseDayKey(
        sorted[i]['endDate']?.toString(),
      );
      if (end != null) {
        final duration = CycleDateContract.daysBetween(start, end) + 1;
        periodDurations.add(duration);
      }

      if (i + 1 < sorted.length) {
        final nextStart = CycleDateContract.parseDayKey(
          sorted[i + 1]['startDate']?.toString(),
        );
        if (nextStart != null) {
          final len = CycleDateContract.daysBetween(start, nextStart);
          if (len > 0) cycleLengths.add(len);
        }
      }
    }

    // 3. Leave-one-out baseline comparison for completed cycles
    if (cycleLengths.isNotEmpty) {
      final lastCycle = cycleLengths.last;

      double referenceAvg;
      if (cycleLengths.length > 1) {
        final previousLengths = cycleLengths.sublist(
          0,
          cycleLengths.length - 1,
        );
        referenceAvg =
            previousLengths.reduce((a, b) => a + b) / previousLengths.length;
      } else {
        referenceAvg = avgCycleLength;
      }

      // Abnormally Short Cycle (< 21 days)
      if (lastCycle < 21) {
        final isSevere = lastCycle <= 18;
        anomalies.add(
          CycleAnomaly(
            type: CycleAnomalyType.abnormallyShortCycle,
            severity: isSevere
                ? CycleAnomalySeverity.consultClinician
                : CycleAnomalySeverity.watch,
            paramValue: lastCycle,
            referenceValue: referenceAvg.round(),
            isMild: !isSevere,
          ),
        );
      }
      // Abnormally Long Cycle (> 38 days)
      else if (lastCycle > 38) {
        final isSevere = lastCycle >= 45;
        anomalies.add(
          CycleAnomaly(
            type: CycleAnomalyType.abnormallyLongCycle,
            severity: isSevere
                ? CycleAnomalySeverity.consultClinician
                : CycleAnomalySeverity.watch,
            paramValue: lastCycle,
            referenceValue: referenceAvg.round(),
            isMild: !isSevere,
          ),
        );
      }
    }

    // 4. Check for unusually long bleeding duration (> 8 days)
    if (periodDurations.isNotEmpty) {
      final lastDuration = periodDurations.last;
      if (lastDuration > 8) {
        final isSevere = lastDuration > 10;
        anomalies.add(
          CycleAnomaly(
            type: CycleAnomalyType.unusuallyLongBleeding,
            severity: isSevere
                ? CycleAnomalySeverity.consultClinician
                : CycleAnomalySeverity.watch,
            paramValue: lastDuration,
            referenceValue: 8,
            isMild: !isSevere,
          ),
        );
      }
    }

    return anomalies;
  }
}
