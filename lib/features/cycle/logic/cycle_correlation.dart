import 'dart:convert';
import 'dart:math' as math;

import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/models/cycle_models.dart';
import 'package:sqflite/sqflite.dart';

class CycleCorrelationAnalyzer {
  /// Shift for night sleep attribution (night of Day N attributes to morning of Day N+1)
  static const int sleepAttributionOffsetDays = 1;

  /// Minimum sample size of paired days for statistical significance
  static const int minSampleSizeForSignificance = 14;

  static Future<List<CycleCorrelation>> analyzeCorrelations(
    Database db, {
    DateTime? now,
    int windowDays = 90,
  }) async {
    final effectiveNow = CycleDateContract.cleanDate(now ?? DateTime.now());
    final windowStartDate = effectiveNow.subtract(Duration(days: windowDays));
    final windowStartKey = CycleDateContract.toDayKey(windowStartDate);
    final windowEndKey = CycleDateContract.toDayKey(effectiveNow);

    // 1. Fetch cycle day logs within window
    final List<Map<String, dynamic>> dayLogs = await db.query(
      'cycle_day_logs',
      where: 'logDate >= ? AND logDate <= ?',
      whereArgs: [windowStartKey, windowEndKey],
      orderBy: 'logDate ASC',
    );

    // 2. Fetch energy logs
    final windowStartMs = windowStartDate.millisecondsSinceEpoch;
    final windowEndMs = effectiveNow
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch;
    final List<Map<String, dynamic>> energyLogs = await db.query(
      'energy_logs',
      where: 'loggedAt >= ? AND loggedAt <= ?',
      whereArgs: [windowStartMs, windowEndMs],
      orderBy: 'loggedAt ASC',
    );

    // 3. Fetch sleep logs (bedtime_diagnostics ordered by date)
    final sleepStartKey = CycleDateContract.toDayKey(
      windowStartDate.subtract(const Duration(days: 2)),
    );
    final List<Map<String, dynamic>> sleepLogs = await db.query(
      'bedtime_diagnostics',
      where: 'date >= ? AND date <= ?',
      whereArgs: [sleepStartKey, windowEndKey],
      orderBy: 'date ASC',
    );

    // 4. Fetch routine completions
    final List<Map<String, dynamic>> completions = await db.query(
      'routine_completions',
      where: 'completionDate >= ? AND completionDate <= ?',
      whereArgs: [windowStartKey, windowEndKey],
      orderBy: 'completionTime ASC',
    );

    // Build merged day-to-day map for full window (including zero-flow days)
    final mergedData = <String, Map<String, dynamic>>{};

    for (final log in dayLogs) {
      final rawDate = log['logDate']?.toString();
      final parsedDate = CycleDateContract.parseDayKey(rawDate);
      if (parsedDate == null) {
        RitmoLogger.warning(
          '[CycleCorrelation] skipping dayLog with invalid date: $rawDate',
        );
        continue;
      }
      final date = CycleDateContract.toDayKey(parsedDate);

      // Flow Level mapped via canonical enum
      final flowStr = log['flowLevel']?.toString();
      final flowEnum = CycleFlowLevel.fromDb(flowStr);
      final flowScore = flowEnum.score;

      var symptomCount = 0;
      final symptomsJson = log['symptomsJson'] as String?;
      if (symptomsJson != null && symptomsJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(symptomsJson);
          if (decoded is List) symptomCount = decoded.length;
        } catch (e, st) {
          RitmoLogger.error(
            '[CycleCorrelation] error decoding symptomsJson',
            error: e,
            stack: st,
          );
        }
      }

      mergedData[date] = {
        'flowScore': flowScore,
        'hasLoggedFlow': true,
        'symptomCount': symptomCount,
        'energy': <double>[],
        'sleepQuality': <double>[],
        'completionCount': 0.0,
      };
    }

    // Map energy logs to dates (converting energyLevel to ordinal scale 1..3)
    for (final log in energyLogs) {
      final loggedAt = log['loggedAt'] as int?;
      if (loggedAt == null) continue;
      final logDate = DateTime.fromMillisecondsSinceEpoch(loggedAt);
      final dateStr = CycleDateContract.toDayKey(logDate);

      if (!mergedData.containsKey(dateStr)) {
        mergedData[dateStr] = {
          'flowScore': 0.0,
          'hasLoggedFlow': false,
          'symptomCount': 0,
          'energy': <double>[],
          'sleepQuality': <double>[],
          'completionCount': 0.0,
        };
      }

      final levelStr = log['energyLevel']?.toString().toUpperCase() ?? 'MEDIUM';
      var score = 2.0; // Medium ordinal
      if (levelStr == 'HIGH') score = 3.0;
      if (levelStr == 'LOW') score = 1.0;
      (mergedData[dateStr]!['energy'] as List<double>).add(score);
    }

    // Map sleep logs with attribution offset
    for (final log in sleepLogs) {
      final dateStr = log['date'] as String?;
      final parsedDate = CycleDateContract.parseDayKey(dateStr);
      if (parsedDate == null) continue;

      // Night of date D applies to Day D + sleepAttributionOffsetDays
      final attributedDate = parsedDate.add(
        const Duration(days: sleepAttributionOffsetDays),
      );
      final attributedDateStr = CycleDateContract.toDayKey(attributedDate);

      if (!mergedData.containsKey(attributedDateStr)) {
        mergedData[attributedDateStr] = {
          'flowScore': 0.0,
          'hasLoggedFlow': false,
          'symptomCount': 0,
          'energy': <double>[],
          'sleepQuality': <double>[],
          'completionCount': 0.0,
        };
      }

      final quality = (log['quality'] as num?)?.toDouble() ?? 3.0; // 1..5
      (mergedData[attributedDateStr]!['sleepQuality'] as List<double>).add(
        quality,
      );
    }

    // Map completions to dates
    for (final comp in completions) {
      final compDate = comp['completionDate'] as String?;
      final parsedDate = CycleDateContract.parseDayKey(compDate);
      if (parsedDate == null) continue;
      final dateStr = CycleDateContract.toDayKey(parsedDate);

      if (!mergedData.containsKey(dateStr)) {
        mergedData[dateStr] = {
          'flowScore': 0.0,
          'hasLoggedFlow': false,
          'symptomCount': 0,
          'energy': <double>[],
          'sleepQuality': <double>[],
          'completionCount': 0.0,
        };
      }

      final resType = comp['resultType'] as String? ?? 'FULL';
      if (resType != 'SNOOZED') {
        mergedData[dateStr]!['completionCount'] =
            (mergedData[dateStr]!['completionCount'] as double) + 1.0;
      }
    }

    // Build paired vectors for days where data exists
    final flowForEnergy = <double>[];
    final energyVector = <double>[];
    final flowForSleep = <double>[];
    final sleepVector = <double>[];
    final flowForComp = <double>[];
    final compVector = <double>[];

    mergedData.forEach((_, map) {
      final flow = map['flowScore'] as double;
      final energyList = map['energy'] as List<double>;
      final sleepList = map['sleepQuality'] as List<double>;
      final completionCount = map['completionCount'] as double;

      if (energyList.isNotEmpty) {
        flowForEnergy.add(flow);
        energyVector.add(
          energyList.reduce((a, b) => a + b) / energyList.length,
        );
      }

      if (sleepList.isNotEmpty) {
        flowForSleep.add(flow);
        sleepVector.add(sleepList.reduce((a, b) => a + b) / sleepList.length);
      }

      if (map['hasLoggedFlow'] == true || completionCount > 0) {
        flowForComp.add(flow);
        compVector.add(completionCount);
      }
    });

    // Compute Spearman rank correlations & p-values
    final energyAnalysis = _analyzeMetric(
      flowForEnergy,
      energyVector,
      'انرژی بدنی',
      '⚡',
    );
    final sleepAnalysis = _analyzeMetric(
      flowForSleep,
      sleepVector,
      'کیفیت خواب',
      '🌙',
    );
    final compAnalysis = _analyzeMetric(
      flowForComp,
      compVector,
      'پایبندی به روتین‌ها',
      '🌸',
    );

    return [energyAnalysis, sleepAnalysis, compAnalysis];
  }

  static CycleCorrelation _analyzeMetric(
    List<double> x,
    List<double> y,
    String metricName,
    String icon,
  ) {
    final n = x.length;
    if (n < minSampleSizeForSignificance) {
      return CycleCorrelation(
        metric: metricName,
        coefficient: null,
        pValue: null,
        sampleSize: n,
        isSignificant: false,
        insight:
            'داده‌های کافی برای محاسبه همبستگی معنادار $metricName وجود ندارد (حداقل $minSampleSizeForSignificance روز ثبت تطبیقی نیاز است).',
      );
    }

    final corr = _calculateSpearman(x, y);
    if (corr == null) {
      return CycleCorrelation(
        metric: metricName,
        coefficient: null,
        pValue: null,
        sampleSize: n,
        isSignificant: false,
        insight:
            'داده‌های ثبت‌شده برای $metricName تغییرات کافی جهت محاسبه همبستگی ندارند.',
      );
    }

    final pValue = _computePValue(corr, n);
    final isSignificant =
        (pValue != null && pValue < 0.05 && corr.abs() >= 0.25);

    String insight;
    if (!isSignificant) {
      insight =
          'همبستگی معناداری بین شدت چرخه و $metricName در داده‌های شما مشاهده نشد. $icon';
    } else if (corr < -0.3) {
      if (metricName == 'انرژی بدنی') {
        insight =
            'در روزهای با شدت جریان بیشتر، سطح انرژی بدنی شما کاهش نسبی نشان می‌دهد که طبیعی است. استراحت بیشتری را برنامه‌ریزی کنید. ⚡';
      } else if (metricName == 'کیفیت خواب') {
        insight =
            'کیفیت خواب شما در روزهای جریان شدیدتر اندکی افت می‌کند. دمای اتاق خواب را ملایم‌تر نگه دارید. 🌙';
      } else {
        insight =
            'پایبندی به برنامه‌ها در روزهای اوج ریتم بدنی کمی سخت‌تر می‌شود؛ پیشنهاد می‌کنیم روتین‌های سبک‌تر را فعال کنید. 🌸';
      }
    } else if (corr > 0.3) {
      if (metricName == 'انرژی بدنی') {
        insight =
            'در روزهای جریان شدیدتر، سطح انرژی شما باثبات یا افزایشی گزارش شده است. ⚡';
      } else if (metricName == 'کیفیت خواب') {
        insight =
            'کیفیت خواب شما در روزهای با ریتم بدنی فعال بهبود می‌یابد. 🌙';
      } else {
        insight =
            'تمرکز و تعهد شما به انجام روتین‌ها در این روزها بالا ارزیابی می‌شود. 🌸';
      }
    } else {
      insight =
          'روال $metricName شما نوسان مستقیمی با شدت فیزیکی چرخه نشان نمی‌دهد. $icon';
    }

    return CycleCorrelation(
      metric: metricName,
      coefficient: corr,
      pValue: pValue,
      sampleSize: n,
      isSignificant: isSignificant,
      insight: insight,
    );
  }

  static double? _calculateSpearman(List<double> x, List<double> y) {
    if (x.length != y.length || x.isEmpty) return null;
    final rx = _rank(x);
    final ry = _rank(y);
    return _calculatePearson(rx, ry);
  }

  static List<double> _rank(List<double> data) {
    final n = data.length;
    final indexed = List.generate(n, (i) => MapEntry(i, data[i]))
      ..sort((a, b) => a.value.compareTo(b.value));

    final ranks = List<double>.filled(n, 0.0);
    var i = 0;
    while (i < n) {
      var j = i;
      while (j + 1 < n && indexed[j + 1].value == indexed[i].value) {
        j++;
      }
      final avgRank = (i + 1 + j + 1) / 2.0;
      for (var k = i; k <= j; k++) {
        ranks[indexed[k].key] = avgRank;
      }
      i = j + 1;
    }
    return ranks;
  }

  static double? _calculatePearson(List<double> x, List<double> y) {
    if (x.length != y.length || x.isEmpty) return null;
    final n = x.length;
    double sumX = 0;
    double sumY = 0;
    double sumX2 = 0;
    double sumY2 = 0;
    double sumXY = 0;

    for (var i = 0; i < n; i++) {
      sumX += x[i];
      sumY += y[i];
      sumX2 += x[i] * x[i];
      sumY2 += y[i] * y[i];
      sumXY += x[i] * y[i];
    }

    final denominator = math.sqrt(
      (n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY),
    );
    if (denominator == 0 || denominator.isNaN) return null;
    return (n * sumXY - sumX * sumY) / denominator;
  }

  static double? _computePValue(double r, int n) {
    if (n <= 2) return null;
    if (r.abs() >= 1.0) return 0.0001;
    final t = (r * math.sqrt(n - 2)) / math.sqrt(1 - r * r);
    final df = n - 2;
    return _approximateTwoTailedPValue(t.abs(), df);
  }

  static double _approximateTwoTailedPValue(double t, int df) {
    if (df <= 0) return 1.0;
    // Normal approximation for Student's t with df correction
    final z = t * (1.0 - (1.0 / (4.0 * df)));
    final pOneTail = 0.5 * (1.0 - _erf(z / math.sqrt(2.0)));
    return (pOneTail * 2.0).clamp(0.0001, 1.0);
  }

  static double _erf(double x) {
    // Abramowitz and Stegun formula 7.1.26
    const a1 = 0.254829592;
    const a2 = -0.284496736;
    const a3 = 1.421413741;
    const a4 = -1.453152027;
    const a5 = 1.061405429;
    const p = 0.3275911;

    final sign = x < 0 ? -1 : 1;
    final absX = x.abs();
    final t = 1.0 / (1.0 + p * absX);
    final y =
        1.0 -
        (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) *
            t *
            math.exp(-absX * absX);
    return sign * y;
  }

  static Future<List<SymptomStat>> analyzeSymptomStats(
    Database db, {
    int defaultCycleLength = 28,
  }) async {
    final List<Map<String, dynamic>> dayLogs = await db.query('cycle_day_logs');
    final List<Map<String, dynamic>> periods = await db.query(
      'cycle_periods',
      orderBy: 'startDate ASC',
    );

    if (dayLogs.isEmpty) return [];

    final symptomCounts = <String, int>{};
    final symptomCycleDays = <String, List<int>>{};

    final maxAllowedCycleDay = defaultCycleLength + 10;

    for (final log in dayLogs) {
      final dateStr = log['logDate']?.toString();
      final logDate = CycleDateContract.parseDayKey(dateStr);
      if (logDate == null) {
        RitmoLogger.warning(
          '[CycleCorrelation] invalid logDate in analyzeSymptomStats: $dateStr',
        );
        continue;
      }

      final symptomsJson = log['symptomsJson'] as String?;
      if (symptomsJson == null || symptomsJson.isEmpty) continue;

      var symptoms = <dynamic>[];
      try {
        final decoded = jsonDecode(symptomsJson);
        if (decoded is List) symptoms = decoded;
      } catch (e, st) {
        RitmoLogger.error(
          '[CycleCorrelation] error decoding symptomsJson in analyzeSymptomStats',
          error: e,
          stack: st,
        );
        continue;
      }

      if (symptoms.isEmpty) continue;

      // Find which cycle day this log corresponds to
      Map<String, dynamic>? activePeriod;
      for (var i = periods.length - 1; i >= 0; i--) {
        final startStr = periods[i]['startDate']?.toString();
        final start = CycleDateContract.parseDayKey(startStr);
        if (start != null && CycleDateContract.isSameOrBefore(start, logDate)) {
          activePeriod = periods[i];
          break;
        }
      }

      if (activePeriod == null) continue;
      final start = CycleDateContract.parseDayKey(
        activePeriod['startDate']?.toString(),
      );
      if (start == null) continue;

      final cycleDay = CycleDateContract.daysBetween(start, logDate) + 1;
      if (cycleDay < 1 || cycleDay > maxAllowedCycleDay) {
        // C-29: Discard logs beyond L + 10
        continue;
      }

      for (final sym in symptoms) {
        final key = sym.toString().trim();
        if (key.isEmpty) continue;
        symptomCounts[key] = (symptomCounts[key] ?? 0) + 1;
        symptomCycleDays.putIfAbsent(key, () => []).add(cycleDay);
      }
    }

    final stats = <SymptomStat>[];
    symptomCounts.forEach((key, count) {
      final days = symptomCycleDays[key] ?? [];
      var typicalDay = 1;
      if (days.isNotEmpty) {
        days.sort();
        typicalDay = days[days.length ~/ 2]; // median
      }
      stats.add(
        SymptomStat(key: key, count: count, typicalCycleDay: typicalDay),
      );
    });

    stats.sort((a, b) => b.count.compareTo(a.count));
    return stats;
  }
}
