import 'dart:async';
import 'dart:math' as math;

import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
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
    final now = DateTime(input.now.year, input.now.month, input.now.day);

    final isFemale = CyclePrivacyGuard.isVisible(appSettings);
    final cycleEnabled = ModuleGate.instance.isEnabledFrom(appSettings, 'module_cycle_enabled');

    if (!isFemale || !cycleEnabled) {
      return _emptyOutput(now);
    }

    // 1. Fetch cycle_periods from database
    final List<Map<String, dynamic>> periodRows = await db.query(
      'cycle_periods',
      orderBy: 'startDate ASC', // Oldest first to compute differences easily
    );

    if (periodRows.isEmpty) {
      return _emptyOutput(now);
    }

    // 2. Parse setting fallbacks
    final defaultCycleLength = int.tryParse(appSettings['cycle_avg_length'] ?? '28') ?? 28;
    final defaultPeriodDuration = int.tryParse(appSettings['cycle_avg_period'] ?? '6') ?? 6;

    // 3. Compute Actual Statistics
    var avgCycleLength = defaultCycleLength.toDouble();
    var avgPeriodDuration = defaultPeriodDuration.toDouble();
    final totalRecordedCycles = periodRows.length;

    // Average cycle length: difference between consecutive cycle start dates
    final cycleLengths = <int>[];
    for (var i = 0; i < periodRows.length - 1; i++) {
      final start1 = _clean(DateTime.parse(periodRows[i]['startDate'] as String));
      final start2 = _clean(DateTime.parse(periodRows[i + 1]['startDate'] as String));
      final diffDays = start2.difference(start1).inDays;
      if (diffDays >= 15 && diffDays <= 50) { // filter out unrealistic outliers
        cycleLengths.add(diffDays);
      }
    }

    if (cycleLengths.isNotEmpty) {
      avgCycleLength = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
    }

    // Average period duration
    final periodDurations = <int>[];
    for (final row in periodRows) {
      final start = _clean(DateTime.parse(row['startDate'] as String));
      final endStr = row['endDate'] as String?;
      if (endStr != null) {
        final end = _clean(DateTime.parse(endStr));
        final duration = end.difference(start).inDays + 1;
        if (duration >= 1 && duration <= 15) {
          periodDurations.add(duration);
        }
      }
    }

    if (periodDurations.isNotEmpty) {
      avgPeriodDuration = periodDurations.reduce((a, b) => a + b) / periodDurations.length;
    }

    // Safe clamped configurations
    var L = avgCycleLength.round();
    if (L < 21) L = 21;
    if (L > 45) L = 45;

    var pDuration = avgPeriodDuration.round();
    if (pDuration < 3) pDuration = 3;
    if (pDuration > 10) pDuration = 10;

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
      final start = _clean(DateTime.parse(periodRows[i]['startDate'] as String));
      final endStr = periodRows[i]['endDate'] as String?;
      var pDays = pDuration;
      if (endStr != null) {
        pDays = _clean(DateTime.parse(endStr)).difference(start).inDays + 1;
      }

      var lenDays = L;
      if (i < periodRows.length - 1) {
        final nextStart = _clean(DateTime.parse(periodRows[i + 1]['startDate'] as String));
        lenDays = nextStart.difference(start).inDays;
      } else if (cycleLengths.isNotEmpty) {
        lenDays = cycleLengths.last;
      }

      trendPoints.add(CycleTrendPoint(
        index: i + 1,
        lengthDays: lenDays,
        periodDays: pDays,
      ));
    }

    final pmsWindowDays = int.tryParse(appSettings['cycle_pms_window_days'] ?? '4') ?? 4;

    // 8. Find current status based on target date `now`
    // Latest period starting on or before `now`
    Map<String, dynamic>? currentPeriodRow;
    for (var i = periodRows.length - 1; i >= 0; i--) {
      final start = _clean(DateTime.parse(periodRows[i]['startDate'] as String));
      if (!start.isAfter(now)) {
        currentPeriodRow = periodRows[i];
        break;
      }
    }

    if (currentPeriodRow == null) {
      // All logged periods start in the future relative to `now`
      // Fallback to using the oldest start date and projecting backwards
      final firstStart = _clean(DateTime.parse(periodRows.first['startDate'] as String));
      final daysDiff = firstStart.difference(now).inDays;
      final cyclesToSubtract = (daysDiff / L).ceil();
      final estimatedPrevStart = firstStart.subtract(Duration(days: cyclesToSubtract * L));

      return _evaluateWithStart(
        estimatedPrevStart,
        now,
        L,
        pDuration,
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

    final currentPeriodStart = _clean(DateTime.parse(currentPeriodRow['startDate'] as String));
    final currentPeriodEndStr = currentPeriodRow['endDate'] as String?;
    final currentPeriodEnd = currentPeriodEndStr != null ? _clean(DateTime.parse(currentPeriodEndStr)) : null;

    return _evaluateWithStart(
      currentPeriodStart,
      now,
      L,
      pDuration,
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
    final cleanNow = DateTime(now.year, now.month, now.day);
    final cleanStart = DateTime(startDate.year, startDate.month, startDate.day);
    final daysSinceStart = cleanNow.difference(cleanStart).inDays;

    var dayOfCycle = (daysSinceStart % L) + 1;
    var dayOfPeriod = 0;
    var phase = CyclePhase.follicular;

    // Check Menstrual Phase
    var isBleeding = false;
    if (daysSinceStart >= 0) {
      if (endDate != null) {
        final cleanEnd = DateTime(endDate.year, endDate.month, endDate.day);
        if (!cleanNow.isAfter(cleanEnd)) {
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
      // Calculate Ovulation Day relative to current prediction cycle start
      final cyclesElapsed = (daysSinceStart / L).floor();
      final currentPredictedStart = cleanStart.add(Duration(days: cyclesElapsed * L));

      final currentDayOfCycle = cleanNow.difference(currentPredictedStart).inDays + 1;
      dayOfCycle = currentDayOfCycle;

      final ovulationDayNum = L - 14;
      if (currentDayOfCycle < ovulationDayNum - 1) {
        phase = CyclePhase.follicular;
      } else if (currentDayOfCycle >= ovulationDayNum - 1 && currentDayOfCycle <= ovulationDayNum + 1) {
        phase = CyclePhase.ovulation;
      } else {
        phase = CyclePhase.luteal;
      }
    }

    // Overdue detection: at least one expected period boundary (start + k*L)
    // has passed with no new period logged. `daysOverdue` counts full days
    // past the most recent expected boundary.
    final missedBoundaries = (daysSinceStart / L).floor();
    final rawOverdueDays = daysSinceStart - missedBoundaries * L;
    final isOverdue = !isBleeding && missedBoundaries >= 1 && rawOverdueDays >= 1;
    final daysOverdue = isOverdue ? rawOverdueDays : 0;

    // Prediction Dates
    // Always project to the nearest upcoming (or today's) boundary, so the
    // prediction is never silently stuck in the past.
    var cyclesElapsedForPrediction = (daysSinceStart / L).ceil();
    if (cyclesElapsedForPrediction < 1) cyclesElapsedForPrediction = 1;
    final nextPeriodPrediction = cleanStart.add(Duration(days: cyclesElapsedForPrediction * L));

    final predictedOvulation = nextPeriodPrediction.subtract(const Duration(days: 14));
    final fertileStart = nextPeriodPrediction.subtract(const Duration(days: 19));
    final fertileEnd = nextPeriodPrediction.subtract(const Duration(days: 14));

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
