// C-16..C-27: CycleEngine Domain Intelligence
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
  dataStale,
  pregnancy,
  noData,
}

enum RegularityLevel {
  regular,
  moderate,
  irregular,
  insufficientData,
  pregnancy,
}

enum CycleDisclaimerCode {
  standardBiologicalEstimate,
  pregnancyModeActive,
  insufficientData,
}

class CycleRegularity {
  const CycleRegularity({
    required this.score,
    required this.level,
    required this.isIrregular,
    required this.sampleSize,
    required this.isComputable,
  });

  final int? score;
  final RegularityLevel level;
  final bool isIrregular;
  final int sampleSize;
  final bool isComputable;
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
    int? recordedPeriods,
    int? completedCycles,
    int? totalRecordedCycles,
  })  : recordedPeriods = recordedPeriods ?? totalRecordedCycles ?? 0,
        completedCycles = completedCycles ?? (recordedPeriods ?? totalRecordedCycles ?? 0);

  final double avgCycleLength;
  final double avgPeriodDuration;
  final int recordedPeriods;
  final int completedCycles;

  int get totalRecordedCycles => recordedPeriods;
}

class CycleEngineOutput {
  CycleEngineOutput({
    required this.currentPhase,
    required this.dayOfCycle,
    required this.dayOfPeriod,
    this.nextPeriodPrediction,
    this.fertileWindowStart,
    this.fertileWindowEnd,
    this.ovulationDay,
    required this.isIrregular,
    required this.stats,
    required this.dataMaturity,
    required this.hasData,
    this.nextPeriodWindowStart,
    this.nextPeriodWindowEnd,
    this.pmsWindowStart,
    this.pmsWindowEnd,
    this.regularityScore,
    required this.trendPoints,
    this.regularityLevel = RegularityLevel.insufficientData,
    this.disclaimerCode = CycleDisclaimerCode.standardBiologicalEstimate,
    String? regularityLabel,
    String? predictionDisclaimer,
    this.isOverdue = false,
    this.daysOverdue = 0,
    this.missedCycles = 0,
    this.needsUserAttention = false,
    this.hasPhaseConflict = false,
    this.hasImplausiblePeriodData = false,
    this.isProjected = false,
    this.discardedOutliers = 0,
  })  : _regularityLabel = regularityLabel,
        _predictionDisclaimer = predictionDisclaimer;

  final CyclePhase currentPhase;
  final int dayOfCycle;
  final int dayOfPeriod;
  final DateTime? nextPeriodPrediction;
  final DateTime? fertileWindowStart;
  final DateTime? fertileWindowEnd;
  final DateTime? ovulationDay;
  final bool isIrregular;
  final CycleStats stats;
  final String dataMaturity; // 'LOW', 'MEDIUM', 'HIGH'
  final bool hasData;

  // v2 Upgraded Fields (nullable as per C-25)
  final DateTime? nextPeriodWindowStart;
  final DateTime? nextPeriodWindowEnd;
  final DateTime? pmsWindowStart;
  final DateTime? pmsWindowEnd;
  final int? regularityScore;
  final List<CycleTrendPoint> trendPoints;

  final RegularityLevel regularityLevel;
  final CycleDisclaimerCode disclaimerCode;
  final String? _regularityLabel;
  final String? _predictionDisclaimer;

  String get regularityLabel {
    if (_regularityLabel != null) return _regularityLabel!;
    switch (regularityLevel) {
      case RegularityLevel.regular:
        return 'منظم';
      case RegularityLevel.moderate:
        return 'نسبتاً منظم';
      case RegularityLevel.irregular:
        return 'نامنظم';
      case RegularityLevel.pregnancy:
        return 'دوران بارداری';
      case RegularityLevel.insufficientData:
        return 'دادهٔ ناکافی';
    }
  }

  String get predictionDisclaimer {
    if (_predictionDisclaimer != null) return _predictionDisclaimer!;
    switch (disclaimerCode) {
      case CycleDisclaimerCode.pregnancyModeActive:
        return 'حالت بارداری فعال است — پیش‌بینی‌های قاعدگی متوقف شده‌اند.';
      case CycleDisclaimerCode.insufficientData:
      case CycleDisclaimerCode.standardBiologicalEstimate:
        return 'توجه: این پیش‌بینی صرفاً یک تخمین بیولوژیک است و جنبه قطعیت پزشکی ندارد. چرخه بدنی شما تحت تأثیر عوامل مختلفی نظیر استرس، بیماری، تغییرات وزن، سفر و داروها قرار می‌گیرد.';
    }
  }

  final bool isOverdue;
  final int daysOverdue;
  final int missedCycles;
  final bool needsUserAttention;
  final bool hasPhaseConflict;
  final bool hasImplausiblePeriodData;
  final bool isProjected;
  final int discardedOutliers;
}

class CycleEngine implements CachedEngine<CycleEngineInput, CycleEngineOutput> {
  static const int minPlausibleCycle = 21;
  static const int maxPlausibleCycle = 45;
  static const int maxPlausiblePeriodDays = 15;

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
      orderBy: 'startDate ASC',
    );

    if (periodRows.isEmpty) {
      return _emptyOutput(now);
    }

    // 2. Parse setting fallbacks using CycleSettings façade
    final defaultCycleLength = CycleSettings.getCycleLength(appSettings);
    final defaultPeriodDuration = CycleSettings.getPeriodDuration(appSettings);
    final lutealPhaseDays = CycleSettings.getLutealPhase(appSettings);

    // 3. Compute Actual Statistics with outlier filtering (C-22)
    var avgCycleLength = defaultCycleLength.toDouble();
    var avgPeriodDuration = defaultPeriodDuration.toDouble();
    final recordedPeriods = periodRows.length;
    var discardedOutliers = 0;

    final cycleLengths = <int>[];
    for (var i = 0; i < periodRows.length - 1; i++) {
      final start1 = CycleDateContract.parseDayKey(periodRows[i]['startDate']?.toString());
      final start2 = CycleDateContract.parseDayKey(periodRows[i + 1]['startDate']?.toString());
      if (start1 != null && start2 != null) {
        final diffDays = CycleDateContract.daysBetween(start1, start2);
        if (diffDays >= minPlausibleCycle && diffDays <= maxPlausibleCycle) {
          cycleLengths.add(diffDays);
        } else {
          discardedOutliers++;
        }
      }
    }

    final completedCycles = cycleLengths.length;

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
        if (duration >= 1 && duration <= maxPlausiblePeriodDays) {
          periodDurations.add(duration);
        }
      }
    }

    if (periodDurations.isNotEmpty) {
      avgPeriodDuration = periodDurations.reduce((a, b) => a + b) / periodDurations.length;
    }

    // Safe clamped configurations
    final L = avgCycleLength.round().clamp(CycleSettings.minCycleLength, CycleSettings.maxCycleLength);
    final pDuration = avgPeriodDuration.round().clamp(CycleSettings.minPeriodDuration, CycleSettings.maxPeriodDuration);

    // 4. Regularity calculation (C-20)
    final regularity = _computeRegularity(cycleLengths);

    // 5. Data Maturity (C-21: calculated on completedCycles)
    final String dataMaturity;
    if (completedCycles < 3) {
      dataMaturity = 'LOW';
    } else if (completedCycles <= 6) {
      dataMaturity = 'MEDIUM';
    } else {
      dataMaturity = 'HIGH';
    }

    // 6. Trend Points (v2 Upgrades, C-45)
    final trendPoints = <CycleTrendPoint>[];
    for (var i = 0; i < periodRows.length; i++) {
      final start = CycleDateContract.parseDayKey(periodRows[i]['startDate']?.toString()) ?? now;
      final end = CycleDateContract.parseDayKey(periodRows[i]['endDate']?.toString());
      var pDays = pDuration;
      if (end != null) {
        pDays = CycleDateContract.daysBetween(start, end) + 1;
      }

      var lenDays = L;
      var isInProgress = false;
      if (i < periodRows.length - 1) {
        final nextStart = CycleDateContract.parseDayKey(periodRows[i + 1]['startDate']?.toString());
        if (nextStart != null) {
          lenDays = CycleDateContract.daysBetween(start, nextStart);
        }
      } else {
        if (cycleLengths.isNotEmpty) {
          lenDays = cycleLengths.last;
        }
        isInProgress = true;
      }

      trendPoints.add(CycleTrendPoint(
        index: i + 1,
        lengthDays: lenDays,
        periodDays: pDays,
        isInProgress: isInProgress,
      ));
    }

    final pmsWindowDays = int.tryParse(appSettings[CycleSettings.keyPmsWindowDays] ?? '4') ?? CycleSettings.defaultPmsWindowDays;

    final stats = CycleStats(
      avgCycleLength: avgCycleLength,
      avgPeriodDuration: avgPeriodDuration,
      recordedPeriods: recordedPeriods,
      completedCycles: completedCycles,
    );

    // 7. Find current status based on target date `now`
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
        regularity,
        stats,
        dataMaturity,
        null,
        trendPoints,
        pmsWindowDays,
        cycleLengths,
        isProjected: true,
        discardedOutliers: discardedOutliers,
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
      regularity,
      stats,
      dataMaturity,
      currentPeriodEnd,
      trendPoints,
      pmsWindowDays,
      cycleLengths,
      isProjected: false,
      discardedOutliers: discardedOutliers,
    );
  }

  static CycleRegularity _computeRegularity(List<int> cycleLengths) {
    if (cycleLengths.length < 3) {
      return const CycleRegularity(
        score: null,
        level: RegularityLevel.insufficientData,
        isIrregular: false,
        sampleSize: 0,
        isComputable: false,
      );
    }

    final n = cycleLengths.length;
    final mean = cycleLengths.reduce((a, b) => a + b) / n;
    final variance = cycleLengths.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / n;
    final sd = math.sqrt(variance);
    final sdPenalty = (sd * 10).round();
    final score = (100 - sdPenalty).clamp(0, 100);

    final RegularityLevel level;
    final bool isIrregular;
    if (sd <= 2.5) {
      level = RegularityLevel.regular;
      isIrregular = false;
    } else if (sd <= 5.0) {
      level = RegularityLevel.moderate;
      isIrregular = false;
    } else {
      level = RegularityLevel.irregular;
      isIrregular = true;
    }

    return CycleRegularity(
      score: score,
      level: level,
      isIrregular: isIrregular,
      sampleSize: n,
      isComputable: true,
    );
  }

  CycleEngineOutput _evaluateWithStart(
    DateTime startDate,
    DateTime now,
    int L,
    int pDuration,
    int lutealPhaseSetting,
    CycleRegularity regularity,
    CycleStats stats,
    String dataMaturity,
    DateTime? endDate,
    List<CycleTrendPoint> trendPoints,
    int pmsWindowDays,
    List<int> cycleLengths, {
    bool isProjected = false,
    int discardedOutliers = 0,
  }) {
    final cleanNow = CycleDateContract.cleanDate(now);
    final cleanStart = CycleDateContract.cleanDate(startDate);
    final daysSinceStart = CycleDateContract.daysBetween(cleanStart, cleanNow);

    // C-23: dayOfCycle is measured from cycle start without modulo reset
    final dayOfCycle = daysSinceStart + 1;
    var dayOfPeriod = 0;
    var hasImplausiblePeriodData = false;

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

    // C-24: dayOfPeriod capped at maxPlausiblePeriodDays
    if (dayOfPeriod > maxPlausiblePeriodDays) {
      dayOfPeriod = maxPlausiblePeriodDays;
      hasImplausiblePeriodData = true;
    }

    // C-19: Luteal days tailored for short cycles so follicular phase >= 10 days
    final lutealDays = math.min(lutealPhaseSetting, math.max(1, L - 10));

    // Overdue tracking (C-18)
    final missedCycles = (daysSinceStart / L).floor();
    final daysOverdue = (!isBleeding && daysSinceStart >= L) ? (daysSinceStart - L) : 0;
    final isOverdue = daysOverdue > 0;
    final needsUserAttention = (!isBleeding && (missedCycles >= 2 || daysOverdue >= 45));

    // Phase determination
    CyclePhase phase;
    if (needsUserAttention) {
      phase = CyclePhase.dataStale;
    } else if (isBleeding) {
      phase = CyclePhase.menstrual;
    } else {
      final currentDayInCycle = (daysSinceStart % L) + 1;
      final ovulationDayNum = L - lutealDays;
      if (currentDayInCycle < ovulationDayNum - 1) {
        phase = CyclePhase.follicular;
      } else if (currentDayInCycle >= ovulationDayNum - 1 && currentDayInCycle <= ovulationDayNum + 1) {
        phase = CyclePhase.ovulation;
      } else {
        phase = CyclePhase.luteal;
      }
    }

    // C-19: Phase conflict check
    final currentDayInCycle = (daysSinceStart % L) + 1;
    final hasPhaseConflict = isBleeding && currentDayInCycle >= (L - lutealDays - 1);

    // Prediction Dates (C-17, C-25)
    DateTime? nextPeriodPrediction;
    DateTime? predictedOvulation;
    DateTime? fertileStart;
    DateTime? fertileEnd;
    DateTime? nextPeriodWindowStart;
    DateTime? nextPeriodWindowEnd;
    DateTime? pmsWindowStart;
    DateTime? pmsWindowEnd;

    if (!needsUserAttention) {
      var cyclesElapsedForPrediction = (daysSinceStart / L).ceil();
      if (cyclesElapsedForPrediction < 1) cyclesElapsedForPrediction = 1;
      nextPeriodPrediction = cleanStart.add(Duration(days: cyclesElapsedForPrediction * L));

      predictedOvulation = nextPeriodPrediction.subtract(Duration(days: lutealDays));
      fertileStart = predictedOvulation.subtract(const Duration(days: 5));
      fertileEnd = predictedOvulation.add(const Duration(days: 1));

      // Upgraded v2 prediction windows with capped width (C-17)
      if (cycleLengths.isNotEmpty) {
        final minL = cycleLengths.reduce(math.min);
        final maxL = cycleLengths.reduce(math.max);
        final k = cyclesElapsedForPrediction;
        final anchor = cleanStart.add(Duration(days: (k - 1) * L));
        var winStart = anchor.add(Duration(days: minL));
        var winEnd = anchor.add(Duration(days: maxL));

        if (winEnd.difference(winStart).inDays > 7) {
          winStart = nextPeriodPrediction.subtract(const Duration(days: 3));
          winEnd = nextPeriodPrediction.add(const Duration(days: 3));
        } else if (winEnd.difference(winStart).inDays < 2) {
          winStart = nextPeriodPrediction.subtract(const Duration(days: 1));
          winEnd = nextPeriodPrediction.add(const Duration(days: 1));
        }

        nextPeriodWindowStart = winStart;
        nextPeriodWindowEnd = winEnd;
      } else {
        nextPeriodWindowStart = nextPeriodPrediction.subtract(const Duration(days: 2));
        nextPeriodWindowEnd = nextPeriodPrediction.add(const Duration(days: 2));
      }

      pmsWindowStart = nextPeriodPrediction.subtract(Duration(days: pmsWindowDays));
      pmsWindowEnd = nextPeriodPrediction.subtract(const Duration(days: 1));
    }

    return CycleEngineOutput(
      currentPhase: phase,
      dayOfCycle: dayOfCycle,
      dayOfPeriod: dayOfPeriod,
      nextPeriodPrediction: nextPeriodPrediction,
      fertileWindowStart: fertileStart,
      fertileWindowEnd: fertileEnd,
      ovulationDay: predictedOvulation,
      isIrregular: regularity.isIrregular,
      stats: stats,
      dataMaturity: dataMaturity,
      hasData: true,
      nextPeriodWindowStart: nextPeriodWindowStart,
      nextPeriodWindowEnd: nextPeriodWindowEnd,
      pmsWindowStart: pmsWindowStart,
      pmsWindowEnd: pmsWindowEnd,
      regularityScore: regularity.score,
      trendPoints: trendPoints,
      regularityLevel: regularity.level,
      disclaimerCode: CycleDisclaimerCode.standardBiologicalEstimate,
      isOverdue: isOverdue,
      daysOverdue: daysOverdue,
      missedCycles: missedCycles,
      needsUserAttention: needsUserAttention,
      hasPhaseConflict: hasPhaseConflict,
      hasImplausiblePeriodData: hasImplausiblePeriodData,
      isProjected: isProjected,
      discardedOutliers: discardedOutliers,
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
    final regularity = _computeRegularity(cycleLengths);
    return _evaluateWithStart(
      startDate,
      now,
      cycleLength,
      periodDuration,
      lutealPhaseDays,
      regularity,
      stats,
      dataMaturity,
      endDate,
      trendPoints,
      pmsWindowDays,
      cycleLengths,
    );
  }

  CycleEngineOutput pregnancyOutputForTesting(DateTime now) => _pregnancyOutput(now);

  CycleEngineOutput _pregnancyOutput(DateTime now) {
    return CycleEngineOutput(
      currentPhase: CyclePhase.pregnancy,
      dayOfCycle: 0,
      dayOfPeriod: 0,
      nextPeriodPrediction: null,
      fertileWindowStart: null,
      fertileWindowEnd: null,
      ovulationDay: null,
      isIrregular: false,
      stats: CycleStats(avgCycleLength: 28, avgPeriodDuration: 6, recordedPeriods: 0, completedCycles: 0),
      dataMaturity: 'HIGH',
      hasData: true,
      nextPeriodWindowStart: null,
      nextPeriodWindowEnd: null,
      pmsWindowStart: null,
      pmsWindowEnd: null,
      regularityScore: null,
      trendPoints: const [],
      regularityLevel: RegularityLevel.pregnancy,
      disclaimerCode: CycleDisclaimerCode.pregnancyModeActive,
      isOverdue: false,
      daysOverdue: 0,
      missedCycles: 0,
      needsUserAttention: false,
      hasPhaseConflict: false,
      hasImplausiblePeriodData: false,
      isProjected: false,
      discardedOutliers: 0,
    );
  }

  CycleEngineOutput _emptyOutput(DateTime now) {
    return CycleEngineOutput(
      currentPhase: CyclePhase.noData,
      dayOfCycle: 0,
      dayOfPeriod: 0,
      nextPeriodPrediction: null,
      fertileWindowStart: null,
      fertileWindowEnd: null,
      ovulationDay: null,
      isIrregular: false,
      stats: CycleStats(avgCycleLength: 28, avgPeriodDuration: 6, recordedPeriods: 0, completedCycles: 0),
      dataMaturity: 'LOW',
      hasData: false,
      nextPeriodWindowStart: null,
      nextPeriodWindowEnd: null,
      pmsWindowStart: null,
      pmsWindowEnd: null,
      regularityScore: null,
      trendPoints: const [],
      regularityLevel: RegularityLevel.insufficientData,
      disclaimerCode: CycleDisclaimerCode.insufficientData,
      isOverdue: false,
      daysOverdue: 0,
      missedCycles: 0,
      needsUserAttention: false,
      hasPhaseConflict: false,
      hasImplausiblePeriodData: false,
      isProjected: false,
      discardedOutliers: 0,
    );
  }

  @override
  Duration get ttl => const Duration(minutes: 60);

  @override
  String fingerprint(CycleEngineInput input) {
    final dayStamp = CycleDateContract.toDayKey(input.now);
    final avgLen = input.appSettings['cycle_avg_length'] ?? '28';
    final avgPeriod = input.appSettings['cycle_avg_period'] ?? '6';
    final pmsWindow = input.appSettings['cycle_pms_window_days'] ?? '4';
    return '$dayStamp|$avgLen|$avgPeriod|$pmsWindow';
  }

  @override
  void invalidate() {
    try {
      RitmoEngineBus.instance.invalidate(CycleEngine);
    } catch (_) {}
  }

  @override
  bool canRun(CycleEngineInput input) {
    final isFemale = CyclePrivacyGuard.isVisible(input.appSettings);
    final cycleEnabled = ModuleGate.instance.isEnabledFrom(input.appSettings, 'module_cycle_enabled');
    return isFemale && cycleEnabled;
  }

  @override
  List<Type> dependencies() => [];
}
