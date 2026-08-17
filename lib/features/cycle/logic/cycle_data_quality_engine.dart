// C-03 & C-33: CycleDataQualityEngine with deterministic date handling and proper observability.
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:sqflite/sqflite.dart';

class CycleDataQualityEngine {
  /// Standard threshold for forgotten open period banner (in days).
  static const int forgottenOpenPeriodThresholdDays = 12;

  static Future<DataQualityReport> evaluateDataQuality({
    required Database db,
    required List<Map<String, dynamic>> periodRows,
    DateTime? now,
    String? todayIso,
  }) async {
    final effectiveNow = now ?? (todayIso != null ? CycleDateContract.parseDayKey(todayIso) : null) ?? DateTime.now();
    final cleanNow = CycleDateContract.cleanDate(effectiveNow);
    final hasEnoughCycles = periodRows.length >= 3;

    // Defensive: callers pass rows in different orderings (the screen uses
    // startDate DESC). Find the truly latest period by startDate.
    bool hasForgottenOpenPeriod = false;
    if (periodRows.isNotEmpty) {
      final sorted = [...periodRows]..sort((a, b) => (a['startDate'] ?? '')
          .toString()
          .compareTo((b['startDate'] ?? '').toString()));
      final latest = sorted.last;
      if (latest['endDate'] == null) {
        final start = CycleDateContract.parseDayKey(latest['startDate']?.toString());
        if (start != null) {
          final daysOpen = CycleDateContract.daysBetween(start, cleanNow);
          if (daysOpen >= forgottenOpenPeriodThresholdDays) {
            hasForgottenOpenPeriod = true;
          }
        }
      }
    }

    // Query recent day logs count (last 30 days)
    final thirtyDaysAgoDate = cleanNow.subtract(const Duration(days: 30));
    final thirtyDaysAgo = CycleDateContract.toDayKey(thirtyDaysAgoDate);
    List<Map<String, dynamic>> recentLogs = [];
    try {
      recentLogs = await db.query(
        'cycle_day_logs',
        where: 'logDate >= ?',
        whereArgs: [thirtyDaysAgo],
      );
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleDataQualityEngine] error querying recent cycle_day_logs',
        error: e,
        stack: st,
      );
    }
    final recentLogsCount = recentLogs.length;
    final hasRecentDailyLogs = recentLogsCount >= 5;

    final warningsFa = <String>[];
    if (periodRows.length < 3) {
      warningsFa.add('کمتر از ۳ چرخه ثبت شده است');
    }
    if (hasForgottenOpenPeriod) {
      warningsFa.add('یک دوره باز قدیمی تعیین تکلیف نشده است');
    }
    if (!hasRecentDailyLogs) {
      warningsFa.add('در ۳۰ روز اخیر ثبت روزانه کمی دارید');
    }

    final qualityLabelFa = periodRows.length >= 5 && hasRecentDailyLogs && !hasForgottenOpenPeriod
        ? 'عالی'
        : (periodRows.length >= 2 && !hasForgottenOpenPeriod ? 'متوسط' : 'نیازمند داده بیشتر');

    return DataQualityReport(
      hasEnoughCycles: hasEnoughCycles,
      hasRecentDailyLogs: hasRecentDailyLogs,
      hasForgottenOpenPeriod: hasForgottenOpenPeriod,
      hasPredictionConfidence: hasEnoughCycles && !hasForgottenOpenPeriod,
      recentLogsCount: recentLogsCount,
      qualityLabelFa: qualityLabelFa,
      warningsFa: warningsFa,
    );
  }
}
