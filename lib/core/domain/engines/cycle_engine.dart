import 'dart:async';
import 'dart:math' as math;

import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:ritmo/features/cycle/models/cycle_models.dart';
import 'package:sqflite/sqflite.dart';

enum CyclePhase {
  menstrual,
  follicular,
  ovulation,
  luteal,
  noData,
}

class CycleEngineInput {

  CycleEngineInput({
    required this.db,
    required this.appSettings,
    required this.now,
  });
  final Database db;
  final Map<String, String> appSettings;
  final DateTime now;
}

class CycleStats {

  CycleStats({
    required this.avgCycleLength,
    required this.avgPeriodDuration,
    required this.totalRecordedCycles,
  });
  final double avgCycleLength;
  final double avgPeriodDuration;
  final int totalRecordedCycles;
}

class CycleEngineOutput {

  CycleEngineOutput({
    required this.currentPhase,
    required this.dayOfCycle,
    required this.dayOfPeriod,
    required this.nextPeriodPrediction,
    required this.fertileWindowStart,
    required this.fertileWindowEnd,
    required this.ovulationDay,
    required this.isIrregular,
    required this.stats,
    required this.dataMaturity,
    required this.hasData,
    required this.nextPeriodWindowStart,
    required this.nextPeriodWindowEnd,
    required this.pmsWindowStart,
    required this.pmsWindowEnd,
    required this.regularityScore,
    required this.trendPoints,
    required this.regularityLabel,
    required this.predictionDisclaimer,
    // Overdue tracking — optional with safe defaults so existing
    // constructions (tests, legacy adapters) keep compiling.
    this.isOverdue = false,
    this.daysOverdue = 0,
  });
  final CyclePhase currentPhase;
  final int dayOfCycle;
  final int dayOfPeriod;
  final DateTime nextPeriodPrediction;
  final DateTime fertileWindowStart;
  final DateTime fertileWindowEnd;
  final DateTime ovulationDay;
  final bool isIrregular;
  final CycleStats stats;
  final String dataMaturity; // 'LOW', 'MEDIUM', 'HIGH'
  final bool hasData;

  // v2 Upgraded Fields
  final DateTime nextPeriodWindowStart;
  final DateTime nextPeriodWindowEnd;
  final DateTime pmsWindowStart;
  final DateTime pmsWindowEnd;
  final int regularityScore;
  final List<CycleTrendPoint> trendPoints;

  // Simplified Engine Fields
  final String regularityLabel;
  final String predictionDisclaimer;

  // Overdue tracking: an expected period boundary passed with no log
  final bool isOverdue;
  final int daysOverdue;
}

class CycleEngine implements CachedEngine<CycleEngineInput, CycleEngineOutput> {
  /// Normalize to a calendar day so mixed stored formats (date-only vs
  /// date-time) never skew day-difference math.
  static DateTime _clean(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Future<CycleEngineOutput> calculate(CycleEngineInput input) async {
    final db = input.db;
    final appSettings = input.appSettings;
    final now = CycleDateContract.cleanDate(input.now);

    final isFemale = CyclePrivacyGuard.isVisible(appSettings);
    final cycleEnabled = ModuleGate.instance.isEnabledFrom(appSettings, 'module_cycle_enabled');

    if (!isFemale || !cycleEnabled) {
      return _emptyOutput(now);
    }

    final isPregnancy = CycleSettings.isPregnancyMode(appSettings);
    if (isPregnancy) {
      return _pregnancyOutput(now);
    }

    // 1. Fetch cycle_periods from database
    final List<Map<String, dynamic>> periodRows = await db.query(
      'cycle_periods',
      orderBy: 'startDate ASC', // Oldest first to compute differences easily
    );

    if (periodRows.isEmpty) {
      return _emptyOutput(now);
    }

    // 2. Parse setting fallbacks using CycleSettings façade
    final defaultCycleLength = CycleSettings.getCycleLength(appSettings);
    final defaultPeriodDuration = CycleSettings.getPeriodDuration(appSettings);
    final lutealPhaseDays = CycleSettings.getLutealPhase(appSettings);

    // 3. Compute Actual Statistics
    var avgCycleLength = defaultCycleLength.toDouble();
    var avgPeriodDuration = defaultPeriodDuration.toDouble();
    final totalRecordedCycles = periodRows.length;

    // Average cycle length: difference between consecutive cycle start dates
    final cycleLengths = <int>[];
    for (var i = 0; i < periodRows.length - 1; i++) {
      final start1 = CycleDateContract.parseDayKey(periodRows[i]['startDate']?.toString());
      final start2 = CycleDateContract.parseDayKey(periodRows[i + 1]['startDate']?.toString());
      if (start1 != null && start2 != null) {
        final diffDays = CycleDateContract.daysBetween(start1, start2);
        if (diffDays >= 15 && diffDays <= 50) { // filter out unrealistic outliers
          cycleLengths.add(diffDays);
        }
      }
    }

    if (cycleLengths.isNotEmpty) {
      avgCycleLength = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
    }

    // Average period duration
    final periodDurations = <int>[];
    for (final row in periodRows) {
      final start = CycleDateContract.parseDayKey(row['startDate']?.toString());
      final end = CycleDateContract.parseDayKey(row['endDate']?.toString());
      if (start != null && end != null) {
        final duration = CycleDateContract.daysBetween(start, end) + 1;
        if (duration >= 1 && duration <= 15) {
          periodDurations.add(duration);
        }
      }
    }

    if (periodDurations.isNotEmpty) {
      avgPeriodDuration = periodDurations.reduce((a, b) => a + b) / periodDurations.length;
    }

    // Safe clamped configurations
    var L = avgCycleLength.round().clamp(CycleSettings.minCycleLength, CycleSettings.maxCycleLength);
    var pDuration = avgPeriodDuration.round().clamp(CycleSettings.minPeriodDuration, CycleSettings.maxPeriodDuration);

    // 4. Determine irregularity (variability)
    var isIrregular = false;
    if (cycleLengths.length >= 3) {
      final minL = cycleLengths.reduce(math.min);
      final maxL = cycleLengths.reduce(math.max);
      if ((maxL - minL) >= 7) {
        isIrregular = true;
      }
    }

    // 5. Data Maturity
    var dataMaturity = 'LOW';
    if (totalRecordedCycles >= 3 && totalRecordedCycles <= 6) {
      dataMaturity = 'MEDIUM';
    } else if (totalRecordedCycles > 6) {
      dataMaturity = 'HIGH';
    }

    // 6. Regularity Score & SD calculation (v2 Upgrades)
    var regularityScore = 100;
    var sd = 2.0;
    if (cycleLengths.length >= 3) {
      final mean = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
      final variance = cycleLengths.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / cycleLengths.length;
      sd = math.sqrt(variance);
      regularityScore = (100 - (sd * 12).round()).clamp(0, 100);
    }

    // 7. Trend Points (v2 Upgrades)
    final trendPoints = <CycleTrendPoint>[];
    for (var i = 0; i < periodRows.length; i++) {
      final start = CycleDateContract.parseDayKey(periodRows[i]['startDate']?.toString()) ?? now;
      final end = CycleDateContract.parseDayKey(periodRows[i]['endDate']?.toString());
      var pDays = pDuration;
      if (end != null) {
        pDays = CycleDateContract.daysBetween(start, end) + 1;
      }

      var lenDays = L;
      if (i < periodRows.length - 1) {
        final nextStart = CycleDateContract.parseDayKey(periodRows[i + 1]['startDate']?.toString());
        if (nextStart != null) {
          lenDays = CycleDateContract.daysBetween(start, nextStart);
        }
      } else if (cycleLengths.isNotEmpty) {
        lenDays = cycleLengths.last;
      }

      trendPoints.add(CycleTrendPoint(
        index: i + 1,
        lengthDays: lenDays,
        periodDays: pDays,
      ));
    }

    final pmsWindowDays = int.tryParse(appSettings[CycleSettings.keyPmsWindowDays] ?? '4') ?? CycleSettings.defaultPmsWindowDays;

    // 8. Find current status based on target date `now`
    Map<String, dynamic>? currentPeriodRow;
    for (var i = periodRows.length - 1; i >= 0; i--) {
      final start = CycleDateContract.parseDayKey(periodRows[i]['startDate']?.toString());
      if (start != null && CycleDateContract.isSameOrBefore(start, now)) {
        currentPeriodRow = periodRows[i];
        break;
      }
    }

    if (currentPeriodRow == null) {
      final firstStart = CycleDateContract.parseDayKey(periodRows.first['startDate']?.toString()) ?? now;
      final daysDiff = CycleDateContract.daysBetween(now, firstStart);
      final cyclesToSubtract = (daysDiff / L).ceil();
      final estimatedPrevStart = firstStart.subtract(Duration(days: cyclesToSubtract * L));

      return _evaluateWithStart(
        estimatedPrevStart,
        now,
        L,
        pDuration,
        lutealPhaseDays,
        isIrregular,
        CycleStats(
          avgCycleLength: avgCycleLength,
          avgPeriodDuration: avgPeriodDuration,
          totalRecordedCycles: totalRecordedCycles,
        ),
        dataMaturity,
        null,
        trendPoints,
        regularityScore,
        pmsWindowDays,
        sd,
        cycleLengths,
      );
    }

    final currentPeriodStart = CycleDateContract.parseDayKey(currentPeriodRow['startDate']?.toString()) ?? now;
    final currentPeriodEnd = CycleDateContract.parseDayKey(currentPeriodRow['endDate']?.toString());

    return _evaluateWithStart(
      currentPeriodStart,
      now,
      L,
      pDuration,
      lutealPhaseDays,
      isIrregular,
      CycleStats(
        avgCycleLength: avgCycleLength,
        avgPeriodDuration: avgPeriodDuration,
        totalRecordedCycles: totalRecordedCycles,
      ),
      dataMaturity,
      currentPeriodEnd,
      trendPoints,
      regularityScore,
      pmsWindowDays,
      sd,
      cycleLengths,
    );
  }

  CycleEngineOutput _evaluateWithStart(
    DateTime startDate,
    DateTime now,
    int L,
    int pDuration,
    int lutealPhaseDays,
    bool isIrregular,
    CycleStats stats,
    String dataMaturity,
    DateTime? endDate,
    List<CycleTrendPoint> trendPoints,
    int regularityScore,
    int pmsWindowDays,
    double sd,
    List<int> cycleLengths,
  ) {
    final cleanNow = CycleDateContract.cleanDate(now);
    final cleanStart = CycleDateContract.cleanDate(startDate);
    final daysSinceStart = CycleDateContract.daysBetween(cleanStart, cleanNow);

    var dayOfCycle = (daysSinceStart % L) + 1;
    var dayOfPeriod = 0;
    var phase = CyclePhase.follicular;

    // Check Menstrual Phase
    var isBleeding = false;
    if (daysSinceStart >= 0) {
      if (endDate != null) {
        final cleanEnd = CycleDateContract.cleanDate(endDate);
        if (CycleDateContract.isSameOrBefore(cleanNow, cleanEnd)) {
          isBleeding = true;
          dayOfPeriod = daysSinceStart + 1;
        }
      } else {
        if (daysSinceStart < pDuration) {
          isBleeding = true;
          dayOfPeriod = daysSinceStart + 1;
        }
      }
    }

    if (isBleeding) {
      phase = CyclePhase.menstrual;
    } else {
      final cyclesElapsed = (daysSinceStart / L).floor();
      final currentPredictedStart = cleanStart.add(Duration(days: cyclesElapsed * L));

      final currentDayOfCycle = CycleDateContract.daysBetween(currentPredictedStart, cleanNow) + 1;
      dayOfCycle = currentDayOfCycle;

      final ovulationDayNum = L - lutealPhaseDays;
      if (currentDayOfCycle < ovulationDayNum - 1) {
        phase = CyclePhase.follicular;
      } else if (currentDayOfCycle >= ovulationDayNum - 1 && currentDayOfCycle <= ovulationDayNum + 1) {
        phase = CyclePhase.ovulation;
      } else {
        phase = CyclePhase.luteal;
      }
    }

    // Overdue detection
    final missedBoundaries = (daysSinceStart / L).floor();
    final rawOverdueDays = daysSinceStart - missedBoundaries * L;
    final isOverdue = !isBleeding && missedBoundaries >= 1 && rawOverdueDays >= 1;
    final daysOverdue = isOverdue ? rawOverdueDays : 0;

    // Prediction Dates
    var cyclesElapsedForPrediction = (daysSinceStart / L).ceil();
    if (cyclesElapsedForPrediction < 1) cyclesElapsedForPrediction = 1;
    final nextPeriodPrediction = cleanStart.add(Duration(days: cyclesElapsedForPrediction * L));

    final predictedOvulation = nextPeriodPrediction.subtract(Duration(days: lutealPhaseDays));
    final fertileStart = predictedOvulation.subtract(const Duration(days: 5));
    final fertileEnd = predictedOvulation.add(const Duration(days: 1));

    // Upgraded v2 prediction windows
    DateTime nextPeriodWindowStart;
    DateTime nextPeriodWindowEnd;

    if (cycleLengths.isNotEmpty) {
      final minL = cycleLengths.reduce(math.min);
      final maxL = cycleLengths.reduce(math.max);
      final k = cyclesElapsedForPrediction;
      nextPeriodWindowStart = cleanStart.add(Duration(days: k * minL));
      nextPeriodWindowEnd = cleanStart.add(Duration(days: k * maxL));

      if (nextPeriodWindowEnd.difference(nextPeriodWindowStart).inDays < 2) {
        nextPeriodWindowStart = nextPeriodPrediction.subtract(const Duration(days: 1));
        nextPeriodWindowEnd = nextPeriodPrediction.add(const Duration(days: 1));
      }
    } else {
      nextPeriodWindowStart = nextPeriodPrediction.subtract(const Duration(days: 2));
      nextPeriodWindowEnd = nextPeriodPrediction.add(const Duration(days: 2));
    }

    final pmsWindowStart = nextPeriodPrediction.subtract(Duration(days: pmsWindowDays));
    final pmsWindowEnd = nextPeriodPrediction.subtract(const Duration(days: 1));

    // Regularity Label
    var regularityLabel = 'دادهٔ ناکافی';
    if (stats.totalRecordedCycles >= 2 && cycleLengths.isNotEmpty) {
      final minL = cycleLengths.reduce(math.min);
      final maxL = cycleLengths.reduce(math.max);
      final range = maxL - minL;
      if (range <= 4) {
        regularityLabel = 'نسبتاً منظم';
      } else {
        regularityLabel = 'نامنظم';
      }
    }

    const predictionDisclaimer = 'توجه: این پیش‌بینی صرفاً یک تخمین بیولوژیک است و جنبه قطعیت پزشکی ندارد. چرخه بدنی شما تحت تأثیر عوامل مختلفی نظیر استرس، بیماری، تغییرات وزن، سفر و داروها قرار می‌گیرد.';

    return CycleEngineOutput(
      currentPhase: phase,
      dayOfCycle: dayOfCycle,
      dayOfPeriod: dayOfPeriod,
      nextPeriodPrediction: nextPeriodPrediction,
      fertileWindowStart: fertileStart,
      fertileWindowEnd: fertileEnd,
      ovulationDay: predictedOvulation,
      isIrregular: isIrregular,
      stats: stats,
      dataMaturity: dataMaturity,
      hasData: true,
      nextPeriodWindowStart: nextPeriodWindowStart,
      nextPeriodWindowEnd: nextPeriodWindowEnd,
      pmsWindowStart: pmsWindowStart,
      pmsWindowEnd: pmsWindowEnd,
      regularityScore: regularityScore,
      trendPoints: trendPoints,
      regularityLabel: regularityLabel,
      predictionDisclaimer: predictionDisclaimer,
      isOverdue: isOverdue,
      daysOverdue: daysOverdue,
    );
  }

  CycleEngineOutput evaluateWithStartForTesting({
    required DateTime startDate,
    required DateTime now,
    required int cycleLength,
    required int periodDuration,
    required int lutealPhaseDays,
    required bool isIrregular,
    required CycleStats stats,
    required String dataMaturity,
    required DateTime? endDate,
    required List<CycleTrendPoint> trendPoints,
    required int regularityScore,
    required int pmsWindowDays,
    required double sd,
    required List<int> cycleLengths,
  }) {
    return _evaluateWithStart(
      startDate,
      now,
      cycleLength,
      periodDuration,
      lutealPhaseDays,
      isIrregular,
      stats,
      dataMaturity,
      endDate,
      trendPoints,
      regularityScore,
      pmsWindowDays,
      sd,
      cycleLengths,
    );
  }

  CycleEngineOutput pregnancyOutputForTesting(DateTime now) => _pregnancyOutput(now);

  CycleEngineOutput _pregnancyOutput(DateTime now) {
    final cleanNow = CycleDateContract.cleanDate(now);
    return CycleEngineOutput(
      currentPhase: CyclePhase.ovulation,
      dayOfCycle: 0,
      dayOfPeriod: 0,
      nextPeriodPrediction: cleanNow.add(const Duration(days: 280)),
      fertileWindowStart: cleanNow,
      fertileWindowEnd: cleanNow,
      ovulationDay: cleanNow,
      isIrregular: false,
      stats: CycleStats(avgCycleLength: 28, avgPeriodDuration: 6, totalRecordedCycles: 0),
      dataMaturity: 'HIGH',
      hasData: true,
      nextPeriodWindowStart: cleanNow,
      nextPeriodWindowEnd: cleanNow,
      pmsWindowStart: cleanNow,
      pmsWindowEnd: cleanNow,
      regularityScore: 100,
      trendPoints: [],
      regularityLabel: 'دوران بارداری',
      predictionDisclaimer: 'حالت بارداری فعال است — پیش‌بینی‌های قاعدگی متوقف شده‌اند.',
      isOverdue: false,
      daysOverdue: 0,
    );
  }

  CycleEngineOutput _emptyOutput(DateTime now) {
    final defaultNextStart = now.add(const Duration(days: 14));
    return CycleEngineOutput(
      currentPhase: CyclePhase.noData,
      dayOfCycle: 0,
      dayOfPeriod: 0,
      nextPeriodPrediction: defaultNextStart,
      fertileWindowStart: defaultNextStart.subtract(const Duration(days: 5)),
      fertileWindowEnd: defaultNextStart,
      ovulationDay: defaultNextStart,
      isIrregular: false,
      stats: CycleStats(avgCycleLength: 28, avgPeriodDuration: 6, totalRecordedCycles: 0),
      dataMaturity: 'LOW',
      hasData: false,
      nextPeriodWindowStart: defaultNextStart.subtract(const Duration(days: 2)),
      nextPeriodWindowEnd: defaultNextStart.add(const Duration(days: 2)),
      pmsWindowStart: defaultNextStart.subtract(const Duration(days: 4)),
      pmsWindowEnd: defaultNextStart.subtract(const Duration(days: 1)),
      regularityScore: 0,
      trendPoints: [],
      regularityLabel: 'دادهٔ ناکافی',
      predictionDisclaimer: 'توجه: این پیش‌بینی صرفاً یک تخمین بیولوژیک است و جنبه قطعیت پزشکی ندارد. چرخه بدنی شما تحت تأثیر عوامل مختلفی نظیر استرس، بیماری، تغییرات وزن، سفر و داروها قرار می‌گیرد.',
      isOverdue: false,
      daysOverdue: 0,
    );
  }

  @override
  Duration get ttl => const Duration(minutes: 60);

  @override
  String fingerprint(CycleEngineInput input) {
    final dayStamp = input.now.toIso8601String().substring(0, 10);
    final avgLen = input.appSettings['cycle_avg_length'] ?? '28';
    final avgPeriod = input.appSettings['cycle_avg_period'] ?? '6';
    final pmsWindow = input.appSettings['cycle_pms_window_days'] ?? '4';
    return '$dayStamp|$avgLen|$avgPeriod|$pmsWindow';
  }

  @override
  void invalidate() {}

  @override
  bool canRun(CycleEngineInput input) {
    // Same gate as calculate(): privacy guard + module toggle.
    // (Previously this required a 'cycle_consent' settings key that nothing
    // in the app ever writes, so every RitmoEngineBus execution threw
    // EngineCannotRunException and the home dashboard never saw cycle data.)
    final isFemale = CyclePrivacyGuard.isVisible(input.appSettings);
    final cycleEnabled = ModuleGate.instance.isEnabledFrom(input.appSettings, 'module_cycle_enabled');
    return isFemale && cycleEnabled;
  }

  @override
  List<Type> dependencies() => [];
}
