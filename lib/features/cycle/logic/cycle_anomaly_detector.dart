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

enum CycleAnomalySeverity {
  info,
  watch,
  consultClinician,
}

class CycleAnomaly {
  const CycleAnomaly({
    required this.type,
    required this.severity,
    required this.titleFa,
    required this.descriptionFa,
    this.isMild = true,
  });

  final CycleAnomalyType type;
  final CycleAnomalySeverity severity;
  final String titleFa;
  final String descriptionFa;
  final bool isMild;
}

class CycleAnomalyDetector {
  static List<CycleAnomaly> detectAnomalies({
    required List<Map<String, dynamic>> periodRows,
    required double avgCycleLength,
    CycleEngineOutput? engineOutput,
    DateTime? now,
  }) {
    final anomalies = <CycleAnomaly>[];
    final effectiveNow = CycleDateContract.cleanDate(now ?? DateTime.now());

    // 1. Check for Late or Missed Period (from engine output or current date vs last start)
    if (engineOutput != null) {
      if (engineOutput.daysOverdue >= 7 || engineOutput.missedCycles >= 1) {
        final isSevere = engineOutput.daysOverdue >= 30 || engineOutput.missedCycles >= 2;
        anomalies.add(
          CycleAnomaly(
            type: CycleAnomalyType.lateOrMissedPeriod,
            severity: isSevere ? CycleAnomalySeverity.consultClinician : CycleAnomalySeverity.watch,
            titleFa: isSevere ? 'تأخیر قابل توجه در شروع دوره' : 'تأخیر در شروع دوره قاعدگی',
            descriptionFa: isSevere
                ? 'بیش از ${engineOutput.daysOverdue} روز از موعد معمول دوره گذشته است. در صورت عدم اطمینان، مشاوره با پزشک متخصص زنان توصیه می‌شود.'
                : 'شروع دوره حدود ${engineOutput.daysOverdue} روز نسبت به میانگین معمول به تعویق افتاده است. این روند را زیر نظر داشته باشید.',
            isMild: !isSevere,
          ),
        );
      }
    }

    if (periodRows.length < 2) return anomalies;

    // Sort periods chronologically ascending
    final sorted = [...periodRows]..sort((a, b) {
        final aStart = a['startDate']?.toString() ?? '';
        final bStart = b['startDate']?.toString() ?? '';
        return aStart.compareTo(bStart);
      });

    // 2. Extract cycle lengths
    final cycleLengths = <int>[];
    final periodDurations = <int>[];

    for (var i = 0; i < sorted.length; i++) {
      final start = CycleDateContract.parseDayKey(sorted[i]['startDate']?.toString());
      if (start == null) continue;

      final end = CycleDateContract.parseDayKey(sorted[i]['endDate']?.toString());
      if (end != null) {
        final duration = CycleDateContract.daysBetween(start, end) + 1;
        periodDurations.add(duration);
      }

      if (i + 1 < sorted.length) {
        final nextStart = CycleDateContract.parseDayKey(sorted[i + 1]['startDate']?.toString());
        if (nextStart != null) {
          final len = CycleDateContract.daysBetween(start, nextStart);
          if (len > 0) cycleLengths.add(len);
        }
      }
    }

    // 3. Leave-one-out baseline comparison for completed cycles
    if (cycleLengths.isNotEmpty) {
      final lastCycle = cycleLengths.last;

      // Compute reference from previous cycles (leave-one-out)
      double referenceAvg;
      if (cycleLengths.length > 1) {
        final previousLengths = cycleLengths.sublist(0, cycleLengths.length - 1);
        referenceAvg = previousLengths.reduce((a, b) => a + b) / previousLengths.length;
      } else {
        referenceAvg = avgCycleLength;
      }

      // Abnormally Short Cycle (< 21 days)
      if (lastCycle < 21) {
        final isSevere = lastCycle <= 18;
        anomalies.add(
          CycleAnomaly(
            type: CycleAnomalyType.abnormallyShortCycle,
            severity: isSevere ? CycleAnomalySeverity.consultClinician : CycleAnomalySeverity.watch,
            titleFa: 'کوتاه بودن طول چرخه اخیر',
            descriptionFa:
                'طول چرخه قبلی شما ($lastCycle روز) کوتاه‌تر از بازه معمول فیزیولوژیک (۲۱ روز) بوده است. در صورت تکرار در چرخه‌های متوالی، بررسی با پزشک پیشنهاد می‌شود.',
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
            severity: isSevere ? CycleAnomalySeverity.consultClinician : CycleAnomalySeverity.watch,
            titleFa: 'طولانی بودن چرخه اخیر',
            descriptionFa:
                'طول چرخه قبلی شما ($lastCycle روز) طولانی‌تر از بازه استاندارد بوده و با میانگین قبلی (${referenceAvg.round()} روز) تفاوت دارد.',
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
            severity: isSevere ? CycleAnomalySeverity.consultClinician : CycleAnomalySeverity.watch,
            titleFa: 'طولانی بودن مدت خونریزی',
            descriptionFa:
                'مدت خونریزی دوره اخیر ($lastDuration روز) بیش از حد معمول (حداکثر ۸ روز) ثبت شده است. در صورت ادامه، مشورت با پزشک زنان توصیه می‌شود.',
            isMild: !isSevere,
          ),
        );
      }
    }

    return anomalies;
  }
}

