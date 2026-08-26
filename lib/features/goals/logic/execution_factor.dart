import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

class ExecutionFactor {
  const ExecutionFactor({required this.value, required this.sampleDays});

  final double value;
  final int sampleDays;

  bool get isReliable => sampleDays >= 5;

  static const fallback = ExecutionFactor(value: 1.0, sampleDays: 0);

  static Future<ExecutionFactor> computeForPastDays({
    int daysHistory = 21,
    DatabaseExecutor? txn,
    double? calibrationAverage,
  }) async {
    // If calibrationAverage is available from past 4 cycles (V-05), prefer it
    if (calibrationAverage != null && calibrationAverage > 0) {
      return ExecutionFactor(value: calibrationAverage, sampleDays: 14);
    }

    try {
      final db = txn ?? await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final startMs = nowMs - (daysHistory * 24 * 3600 * 1000);

      // Single aggregate query across completions
      final res = await db.rawQuery('''
        SELECT 
          COUNT(DISTINCT substr(datetime(completionTime / 1000, 'unixepoch'), 1, 10)) as sampleDays,
          COUNT(*) as doneCount
        FROM routine_completions
        WHERE completionTime >= ? AND resultType = 'DONE'
      ''', [startMs]);

      if (res.isNotEmpty) {
        final sampleDays = (res.first['sampleDays'] as num?)?.toInt() ?? 0;
        final doneCount = (res.first['doneCount'] as num?)?.toInt() ?? 0;

        if (sampleDays >= 5) {
          // Calculate factor: ratio of completed to expected (baseline 3 per day)
          final expected = sampleDays * 3;
          final factor = (doneCount / (expected == 0 ? 1 : expected)).clamp(0.4, 1.1);
          return ExecutionFactor(value: factor, sampleDays: sampleDays);
        }
      }
    } catch (e, st) {
      RitmoLogger.warning(
        'ExecutionFactor.computeForPastDays fallback to 1.0: $e',
        error: e,
        stack: st,
      );
    }

    return fallback;
  }
}
