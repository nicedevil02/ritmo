import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:sqflite/sqflite.dart';

class CycleDataQualityEngine {
  static Future<DataQualityReport> evaluateDataQuality({
    required Database db,
    required List<Map<String, dynamic>> periodRows,
    required String todayIso,
  }) async {
    final hasEnoughCycles = periodRows.length >= 3;

    // Defensive: callers pass rows in different orderings (the screen uses
    // startDate DESC). Find the truly latest period by startDate.
    // Threshold matches the screen's forgotten-period banner (>= 12 days).
    bool hasForgottenOpenPeriod = false;
    if (periodRows.isNotEmpty) {
      final sorted = [...periodRows]..sort((a, b) => (a['startDate'] ?? '')
          .toString()
          .compareTo((b['startDate'] ?? '').toString()));
      final latest = sorted.last;
      if (latest['endDate'] == null) {
        final start = DateTime.tryParse(latest['startDate'] as String? ?? '');
        if (start != null) {
          final daysOpen = DateTime.now().difference(start).inDays;
          if (daysOpen >= 12) {
            hasForgottenOpenPeriod = true;
          }
        }
      }
    }

    // Query recent day logs count (last 30 days)
    // NOTE: the column is `logDate` (not `date`).
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);
    List<Map<String, dynamic>> recentLogs = [];
    try {
      recentLogs = await db.query(
        'cycle_day_logs',
        where: 'logDate >= ?',
        whereArgs: [thirtyDaysAgo],
      );
    } catch (_) {}
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
