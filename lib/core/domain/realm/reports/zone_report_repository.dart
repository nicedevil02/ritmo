import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/realm/budgets/zone_budget_repository.dart';
import 'package:ritmo/core/domain/realm/reports/zone_report_models.dart';
import 'package:sqflite/sqflite.dart';

/// Aggregates and generates weekly realm presence reports (F-15).
class ZoneReportRepository {
  ZoneReportRepository({
    DatabaseHelper? dbHelper,
    ZoneBudgetRepository? budgetRepo,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _budgetRepo = budgetRepo ?? ZoneBudgetRepository(dbHelper: dbHelper);

  final DatabaseHelper _dbHelper;
  final ZoneBudgetRepository _budgetRepo;

  /// Generates a weekly realm report for the given time range.
  Future<WeeklyRealmReport> generateWeeklyReport({
    DateTime? now,
    DateTime? startRange,
    DateTime? endRange,
    DatabaseExecutor? executor,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final effectiveEnd = endRange ?? effectiveNow;
    final effectiveStart = startRange ??
        effectiveEnd.subtract(const Duration(days: 7));

    final db = executor ?? await _dbHelper.database;

    // 1. Query current window aggregated minutes
    final currentRows = await _queryAggregatedSessions(
      db,
      effectiveStart.millisecondsSinceEpoch,
      effectiveEnd.millisecondsSinceEpoch,
      effectiveNow.millisecondsSinceEpoch,
    );

    // 2. Query previous window (for week-over-week comparison)
    final prevDuration = effectiveEnd.difference(effectiveStart);
    final prevStart = effectiveStart.subtract(prevDuration);
    final prevEnd = effectiveStart;

    final prevRows = await _queryAggregatedSessions(
      db,
      prevStart.millisecondsSinceEpoch,
      prevEnd.millisecondsSinceEpoch,
      effectiveNow.millisecondsSinceEpoch,
    );

    final prevMinutesMap = <String, int>{};
    for (final row in prevRows) {
      final zoneId = row['zoneId'] as String;
      final minutes = (row['minutes'] as num?)?.toInt() ?? 0;
      prevMinutesMap[zoneId] = minutes;
    }

    // 3. Load all budgets
    final budgets = await _budgetRepo.loadAllBudgets(executor: db);
    final budgetMap = {for (final b in budgets) b.zoneId: b};

    // 4. Map into ZoneReportItem
    final items = <ZoneReportItem>[];
    for (final row in currentRows) {
      final zoneId = row['zoneId'] as String;
      final name = row['name'] as String? ?? 'قلمرو';
      final colorHex = row['color'] as String? ?? '#6366F1';
      final icon = row['icon'] as String? ?? '🎯';
      final minutes = (row['minutes'] as num?)?.toInt() ?? 0;
      final sessionCount = (row['sessionCount'] as num?)?.toInt() ?? 0;

      items.add(
        ZoneReportItem(
          zoneId: zoneId,
          name: name,
          colorHex: colorHex,
          icon: icon,
          totalMinutes: minutes,
          sessionCount: sessionCount,
          previousWeekMinutes: prevMinutesMap[zoneId],
          budget: budgetMap[zoneId],
        ),
      );
    }

    return WeeklyRealmReport(
      startRange: effectiveStart,
      endRange: effectiveEnd,
      items: items,
    );
  }

  Future<List<Map<String, dynamic>>> _queryAggregatedSessions(
    DatabaseExecutor db,
    int startMs,
    int endMs,
    int nowMs,
  ) async {
    return db.rawQuery(
      '''
      SELECT z.id AS zoneId,
             z.name,
             z.color,
             z.icon,
             SUM((COALESCE(s.endedAt, ?) - s.startedAt) / 60000) AS minutes,
             COUNT(*) AS sessionCount
        FROM zone_sessions s
        JOIN zones z ON z.id = s.zoneId
       WHERE s.startedAt >= ? AND s.startedAt < ?
       GROUP BY z.id
       ORDER BY minutes DESC;
      ''',
      [nowMs, startMs, endMs],
    );
  }
}
