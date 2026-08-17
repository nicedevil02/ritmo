import 'dart:convert';

import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:sqflite/sqflite.dart';

class CyclePersonalPatternEngine {
  static Future<List<SymptomForecast>> computePersonalForecasts({
    required Database db,
    required List<Map<String, dynamic>> periodRows,
    required double avgCycleLength,
  }) async {
    if (periodRows.length < 2) return [];

    try {
      final dayLogs = await db.query('cycle_day_logs');
      if (dayLogs.isEmpty) return [];

      // Normalize period starts (ascending) for cycle-day attribution.
      final periodStarts = <DateTime>[];
      for (final p in periodRows) {
        final pStart = DateTime.tryParse(p['startDate'] as String? ?? '');
        if (pStart != null) {
          periodStarts.add(DateTime(pStart.year, pStart.month, pStart.day));
        }
      }
      if (periodStarts.isEmpty) return [];
      periodStarts.sort();

      // Group symptoms by cycle day
      final symptomDayCounts = <String, Map<int, int>>{};

      for (final log in dayLogs) {
        // NOTE: the column is `logDate` (not `date`), and symptoms live in
        // `symptomsJson` as a JSON-encoded array (not a CSV string).
        final dateStr = log['logDate'] as String?;
        if (dateStr == null) continue;
        final logDateRaw = DateTime.tryParse(dateStr);
        if (logDateRaw == null) continue;
        final logDate = DateTime(logDateRaw.year, logDateRaw.month, logDateRaw.day);

        // Attribute the log to the LATEST period start <= logDate, exactly once.
        DateTime? activeStart;
        for (final pStart in periodStarts) {
          if (pStart.isAfter(logDate)) break;
          activeStart = pStart;
        }
        if (activeStart == null) continue;

        final cycleDay = logDate.difference(activeStart).inDays + 1;
        if (cycleDay < 1 || cycleDay > avgCycleLength + 5) continue;

        final symptomsRaw = log['symptomsJson'] as String? ?? '';
        if (symptomsRaw.isEmpty) continue;

        List<String> symptoms;
        try {
          final decoded = jsonDecode(symptomsRaw);
          if (decoded is! List) continue;
          symptoms = decoded.map((e) => e.toString()).toList();
        } catch (e, st) {
          RitmoLogger.error(
            '[CyclePersonalPatternEngine] error decoding symptomsJson',
            error: e,
            stack: st,
          );
          continue;
        }

        for (final sym in symptoms) {
          final key = sym.trim();
          if (key.isEmpty) continue;
          symptomDayCounts.putIfAbsent(key, () => {});
          symptomDayCounts[key]![cycleDay] = (symptomDayCounts[key]![cycleDay] ?? 0) + 1;
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

        if (maxCount >= 2) {
          final confidence = (maxCount / periodRows.length).clamp(0.4, 0.95);
          final labelFa = _getSymptomFarsiLabel(symptomKey);
          forecasts.add(SymptomForecast(
            symptomKey: symptomKey,
            likelyCycleDay: maxDay,
            confidence: confidence,
            insightFa: 'در داده‌های ثبت‌شده شما، $labelFa معمولاً حوالی روز $maxDay چرخه تکرار شده است.',
          ));
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

  static String _getSymptomFarsiLabel(String key) {
    return switch (key.toLowerCase()) {
      'cramps' => 'گرفتگی و درد شکمی',
      'headache' => 'سردرد',
      'bloating' => 'نفخ',
      'backache' => 'کمردرد',
      'mood_swings' => 'نوسانات خلقی',
      'fatigue' => 'خستگی',
      'acne' => 'جوش پوستی',
      _ => key,
    };
  }
}
