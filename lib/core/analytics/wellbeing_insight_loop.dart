import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:sqflite/sqflite.dart';

class WellbeingInsightLoopState {
  const WellbeingInsightLoopState({
    required this.kindName,
    required this.date,
    required this.metric,
  });

  final String kindName;
  final String date;
  final double metric;
}

class WellbeingLoopOutcome {
  const WellbeingLoopOutcome({
    required this.previousKindName,
    required this.improved,
    required this.days,
  });

  final String previousKindName;
  final bool improved;
  final int days;
}

/// Stores the featured narrative of the day and later asks if it helped.
class WellbeingInsightLoop {
  const WellbeingInsightLoop();

  static const String kindKey = 'wellbeing_loop_kind';
  static const String dateKey = 'wellbeing_loop_date';
  static const String metricKey = 'wellbeing_loop_metric';
  static const int minDaysBeforeOutcome = 7;

  static Future<WellbeingInsightLoopState?> load(dynamic db) async {
    try {
      final rows = await db.query(
        'app_settings',
        where: 'key IN (?, ?, ?)',
        whereArgs: [kindKey, dateKey, metricKey],
      );
      String? kindName;
      String? date;
      double? metric;
      for (final row in rows) {
        final key = row['key'] as String?;
        final value = row['value'] as String?;
        if (key == kindKey) kindName = value;
        if (key == dateKey) date = value;
        if (key == metricKey) metric = double.tryParse(value ?? '');
      }
      if (kindName == null || date == null || metric == null) return null;
      return WellbeingInsightLoopState(
        kindName: kindName,
        date: date,
        metric: metric,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveIfNewDay({
    required dynamic db,
    required DateTime now,
    required String kindName,
    required WellbeingInsightLoopState? previous,
    required double? metric,
  }) async {
    final today = RitmoDate.dayKey(now);
    if (previous?.date == today) return;
    if (kindName == 'loopOutcome') {
      kindName = previous?.kindName ?? kindName;
    }
    if (kindName == 'loopOutcome' || metric == null) return;

    final nowMs = now.millisecondsSinceEpoch;
    try {
      for (final entry in {
        kindKey: kindName,
        dateKey: today,
        metricKey: metric.toString(),
      }.entries) {
        await db.insert(
          'app_settings',
          {
            'key': entry.key,
            'value': entry.value,
            'updatedAt': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (_) {}
  }

  static WellbeingLoopOutcome? evaluate({
    required WellbeingInsightLoopState? previous,
    required DateTime now,
    required Map<String, double> currentMetrics,
  }) {
    if (previous == null || previous.kindName == 'loopOutcome') return null;
    final prevDate = RitmoDate.tryParseDayKey(previous.date);
    if (prevDate == null) return null;
    final days =
        RitmoDate.startOfDay(now).difference(RitmoDate.startOfDay(prevDate)).inDays;
    if (days < minDaysBeforeOutcome) return null;
    final current = currentMetrics[previous.kindName];
    if (current == null) return null;
    return WellbeingLoopOutcome(
      previousKindName: previous.kindName,
      improved: current - previous.metric >= thresholdFor(previous.kindName),
      days: days,
    );
  }

  static double thresholdFor(String kindName) {
    switch (kindName) {
      case 'reflectionStreak':
      case 'reflectionLink':
        return 1.0;
      case 'balanceTrend':
      case 'indexDriver':
        return 3.0;
      default:
        return 0.25;
    }
  }
}
