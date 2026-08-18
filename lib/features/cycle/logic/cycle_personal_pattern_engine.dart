import 'dart:convert';

import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:sqflite/sqflite.dart';

class CyclePersonalPatternEngine {
  /// Minimum completed cycles required before releasing statistical forecasts
  static const int minCompletedCycles =
      CycleSettings.minCyclesForReliableForecast;

  /// Minimum occurrences of a symptom on a given cycle day
  static const int minSymptomOccurrences = 3;

  /// Minimum confidence ratio
  static const double minConfidenceThreshold = 0.5;

  static Future<List<SymptomForecast>> computePersonalForecasts({
    required Database db,
    required List<Map<String, dynamic>> periodRows,
    required double avgCycleLength,
    DateTime? now,
  }) async {
    // Need at least 3 periods to have completed cycles
    if (periodRows.length < minCompletedCycles) return [];

    try {
      final dayLogs = await db.query('cycle_day_logs');
      if (dayLogs.isEmpty) return [];

      // Sort period starts chronologically ascending
      final periodStarts = <DateTime>[];
      for (final p in periodRows) {
        final rawStart = p['startDate']?.toString();
        final pStart = CycleDateContract.parseDayKey(rawStart);
        if (pStart != null) {
          periodStarts.add(pStart);
        }
      }
      if (periodStarts.length < minCompletedCycles) return [];
      periodStarts.sort();

      final completedCycles = periodStarts.length - 1;
      if (completedCycles < minCompletedCycles) return [];

      // Map of cycle index to (start, length)
      final cycleMeta = <int, ({DateTime start, int length})>{};
      for (var i = 0; i < periodStarts.length; i++) {
        final start = periodStarts[i];
        final length = (i + 1 < periodStarts.length)
            ? CycleDateContract.daysBetween(start, periodStarts[i + 1])
            : avgCycleLength.round();
        cycleMeta[i] = (start: start, length: length);
      }

      // Group symptoms by symptomKey -> cycleDay -> count
      final symptomDayCounts = <String, Map<int, int>>{};

      final effectiveNow = now != null
          ? CycleDateContract.cleanDate(now)
          : CycleClock.now;

      for (final log in dayLogs) {
        final dateStr = log['logDate']?.toString();
        final logDate = CycleDateContract.parseDayKey(dateStr);
        if (logDate == null) continue;
        if (!CycleDateContract.isSameOrBefore(logDate, effectiveNow)) continue;

        // Find which cycle this log belongs to
        int? activeCycleIndex;
        for (var i = periodStarts.length - 1; i >= 0; i--) {
          if (CycleDateContract.isSameOrBefore(periodStarts[i], logDate)) {
            activeCycleIndex = i;
            break;
          }
        }
        if (activeCycleIndex == null) continue;

        final meta = cycleMeta[activeCycleIndex]!;
        final cycleDay = CycleDateContract.daysBetween(meta.start, logDate) + 1;

        // C-34: Attribution distance cap (L + 10)
        if (cycleDay < 1 || cycleDay > meta.length + 10) continue;

        final symptomsRaw = log['symptomsJson'] as String? ?? '';
        if (symptomsRaw.isEmpty) continue;

        List<dynamic> symptoms;
        try {
          final decoded = jsonDecode(symptomsRaw);
          if (decoded is! List) continue;
          symptoms = decoded;
        } catch (e, st) {
          RitmoLogger.error(
            '[CyclePersonalPatternEngine] error decoding symptomsJson',
            error: e,
            stack: st,
          );
          continue;
        }

        for (final sym in symptoms) {
          final key = sym.toString().trim();
          if (key.isEmpty) continue;
          symptomDayCounts.putIfAbsent(key, () => {});
          symptomDayCounts[key]![cycleDay] =
              (symptomDayCounts[key]![cycleDay] ?? 0) + 1;
        }
      }

      final forecasts = <SymptomForecast>[];

      symptomDayCounts.forEach((symptomKey, dayMap) {
        if (dayMap.isEmpty) return;
        var maxDay = 1;
        var maxCount = 0;
        dayMap.forEach((day, count) {
          if (count > maxCount) {
            maxCount = count;
            maxDay = day;
          }
        });

        // C-34: Thresholds: confidence >= 0.5 && maxCount >= 3 && completedCycles >= 3
        if (maxCount >= minSymptomOccurrences) {
          final confidence = maxCount / completedCycles;
          if (confidence >= minConfidenceThreshold) {
            forecasts.add(
              SymptomForecast(
                symptomKey: symptomKey,
                likelyCycleDay: maxDay,
                confidence: confidence.clamp(0.0, 1.0),
              ),
            );
          }
        }
      });

      forecasts.sort((a, b) => b.confidence.compareTo(a.confidence));
      return forecasts.take(3).toList();
    } catch (e, st) {
      RitmoLogger.error(
        '[CyclePersonalPatternEngine] error in computePersonalForecasts',
        error: e,
        stack: st,
      );
      return [];
    }
  }
}
