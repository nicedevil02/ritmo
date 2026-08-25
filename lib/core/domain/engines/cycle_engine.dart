// ignore_for_file: prefer_initializing_formals
// C-16..C-27: CycleEngine Domain Intelligence
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:ritmo/features/cycle/models/cycle_forecast_models.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
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
    this.sdDays,
  });

  final int? score;
  final RegularityLevel level;
  final bool isIrregular;
  final int sampleSize;
  final bool isComputable;
  final double? sdDays;
}

class CycleEngineInput {
  CycleEngineInput({
    required this.db,
    required this.appSettings,
    required this.now,
    this.horizonCycles = 12,
  });
  final DatabaseExecutor db;
  final Map<String, String> appSettings;
  final DateTime now;
  final int horizonCycles;
}

class CycleStats {
  CycleStats({
    required this.avgCycleLength,
    required this.avgPeriodDuration,
    int? recordedPeriods,
    int? completedCycles,
    int? totalRecordedCycles,
  }) : recordedPeriods = recordedPeriods ?? totalRecordedCycles ?? 0,
       completedCycles =
           completedCycles ?? (recordedPeriods ?? totalRecordedCycles ?? 0);

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
    DateTime? nextPeriodPrediction,
    DateTime? fertileWindowStart,
    DateTime? fertileWindowEnd,
    DateTime? ovulationDay,
    required this.isIrregular,
    required this.stats,
    required this.dataMaturity,
    required this.hasData,
    DateTime? nextPeriodWindowStart,
    DateTime? nextPeriodWindowEnd,
    DateTime? pmsWindowStart,
    DateTime? pmsWindowEnd,
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
    this.cycleLengthSd,
    this.forecastAnchor,
    this.forecast = const [],
    this.isBleedingConfirmed = false,
    this.isOpenPeriodBeyondAverage = false,
    this.openPeriodDayCount = 0,
    this.actualPeriodStart,
    this.isStartDueToday = false,
    this.missedExpectedStarts = const [],
    this.awaitingStartConfirmation = false,
    this.awaitingEndConfirmation = false,
  }) : _nextPeriodPrediction = nextPeriodPrediction,
       _fertileWindowStart = fertileWindowStart,
       _fertileWindowEnd = fertileWindowEnd,
       _ovulationDay = ovulationDay,
       _nextPeriodWindowStart = nextPeriodWindowStart,
       _nextPeriodWindowEnd = nextPeriodWindowEnd,
       _pmsWindowStart = pmsWindowStart,
       _pmsWindowEnd = pmsWindowEnd,
       _regularityLabel = regularityLabel,
       _predictionDisclaimer = predictionDisclaimer;

  final CyclePhase currentPhase;
  final int dayOfCycle;
  final int dayOfPeriod;
  final bool isIrregular;
  final CycleStats stats;
  final String dataMaturity; // 'LOW', 'MEDIUM', 'HIGH'
  final bool hasData;

  final int? regularityScore;
  final List<CycleTrendPoint> trendPoints;

  final RegularityLevel regularityLevel;
  final CycleDisclaimerCode disclaimerCode;
  final String? _regularityLabel;
  final String? _predictionDisclaimer;

  String get regularityLabel =>
      _regularityLabel ??
      switch (regularityLevel) {
        RegularityLevel.regular => 'کاملاً منظم',
        RegularityLevel.moderate => 'نسبتاً منظم',
        RegularityLevel.irregular => 'نامنظم',
        RegularityLevel.insufficientData => 'داده ناکافی',
        RegularityLevel.pregnancy => 'دوران بارداری',
      };

  String get predictionDisclaimer =>
      _predictionDisclaimer ??
      switch (disclaimerCode) {
        CycleDisclaimerCode.standardBiologicalEstimate =>
          'پیش‌بینی بر اساس میانگین بیولوژیکی استاندارد انجام شده است.',
        CycleDisclaimerCode.pregnancyModeActive =>
          'حالت بارداری فعال است و محاسبات چرخه متوقف شده است.',
        CycleDisclaimerCode.insufficientData =>
          'داده‌های ثبت‌شده برای تحلیل دقیق‌تر چرخه کافی نیست.',
      };

  final bool isOverdue;
  final int daysOverdue;
  final int missedCycles;
  final bool needsUserAttention;
  final bool hasPhaseConflict;
  final bool hasImplausiblePeriodData;
  final bool isProjected;
  final int discardedOutliers;

  final double? cycleLengthSd;
  final DateTime? forecastAnchor;
  final List<PredictedCycle> forecast;

  /// آیا خونریزی امروز از رکورد واقعی کاربر استنتاج شده (نه از میانگین)؟
  final bool isBleedingConfirmed;

  /// دورهٔ بازِ فعلی از میانگین طول دورهٔ کاربر گذشته است.
  final bool isOpenPeriodBeyondAverage;

  /// شمارهٔ روز دورهٔ باز فعلی (۰ اگر دورهٔ بازی نیست).
  final int openPeriodDayCount;

  /// تاریخ شروع آخرین دورهٔ واقعیِ ثبت‌شده.
  final DateTime? actualPeriodStart;

  /// امروز دقیقاً موعد تخمینی شروع است.
  final bool isStartDueToday;

  /// موعدهای تخمینی گذشته که کاربر شروعی ثبت نکرده — قدیمی‌ترین اول.
  final List<DateTime> missedExpectedStarts;

  /// منتظر تأیید کاربر برای شروع.
  final bool awaitingStartConfirmation;

  /// منتظر تأیید کاربر برای پایان.
  final bool awaitingEndConfirmation;

  // Backward-compatible single-cycle getters derived from forecast.first (T-2, F-17)
  final DateTime? _nextPeriodPrediction;
  final DateTime? _fertileWindowStart;
  final DateTime? _fertileWindowEnd;
  final DateTime? _ovulationDay;
  final DateTime? _nextPeriodWindowStart;
  final DateTime? _nextPeriodWindowEnd;
  final DateTime? _pmsWindowStart;
  final DateTime? _pmsWindowEnd;

  DateTime? get nextPeriodPrediction =>
      _nextPeriodPrediction ??
      (forecast.isNotEmpty ? forecast.first.predictedStart : null);

  DateTime? get fertileWindowStart =>
      _fertileWindowStart ??
      (forecast.isNotEmpty ? forecast.first.fertileStart : null);

  DateTime? get fertileWindowEnd =>
      _fertileWindowEnd ??
      (forecast.isNotEmpty ? forecast.first.fertileEnd : null);

  DateTime? get ovulationDay =>
      _ovulationDay ??
      (forecast.isNotEmpty ? forecast.first.ovulationDay : null);

  DateTime? get nextPeriodWindowStart =>
      _nextPeriodWindowStart ??
      (forecast.isNotEmpty ? forecast.first.windowStart : null);

  DateTime? get nextPeriodWindowEnd =>
      _nextPeriodWindowEnd ??
      (forecast.isNotEmpty ? forecast.first.windowEnd : null);

  DateTime? get pmsWindowStart =>
      _pmsWindowStart ?? (forecast.isNotEmpty ? forecast.first.pmsStart : null);

  DateTime? get pmsWindowEnd =>
      _pmsWindowEnd ?? (forecast.isNotEmpty ? forecast.first.pmsEnd : null);

  CycleEngineOutput copyWith({
    CyclePhase? currentPhase,
    int? dayOfCycle,
    int? dayOfPeriod,
    DateTime? nextPeriodPrediction,
    DateTime? fertileWindowStart,
    DateTime? fertileWindowEnd,
    DateTime? ovulationDay,
    bool? isIrregular,
    CycleStats? stats,
    String? dataMaturity,
    bool? hasData,
    DateTime? nextPeriodWindowStart,
    DateTime? nextPeriodWindowEnd,
    DateTime? pmsWindowStart,
    DateTime? pmsWindowEnd,
    int? regularityScore,
    List<CycleTrendPoint>? trendPoints,
    RegularityLevel? regularityLevel,
    CycleDisclaimerCode? disclaimerCode,
    String? regularityLabel,
    String? predictionDisclaimer,
    bool? isOverdue,
    int? daysOverdue,
    int? missedCycles,
    bool? needsUserAttention,
    bool? hasPhaseConflict,
    bool? hasImplausiblePeriodData,
    bool? isProjected,
    int? discardedOutliers,
    double? cycleLengthSd,
    DateTime? forecastAnchor,
    List<PredictedCycle>? forecast,
    bool? isBleedingConfirmed,
    bool? isOpenPeriodBeyondAverage,
    int? openPeriodDayCount,
    DateTime? actualPeriodStart,
    bool? isStartDueToday,
    List<DateTime>? missedExpectedStarts,
    bool? awaitingStartConfirmation,
    bool? awaitingEndConfirmation,
  }) {
    return CycleEngineOutput(
      currentPhase: currentPhase ?? this.currentPhase,
      dayOfCycle: dayOfCycle ?? this.dayOfCycle,
      dayOfPeriod: dayOfPeriod ?? this.dayOfPeriod,
      nextPeriodPrediction: nextPeriodPrediction ?? _nextPeriodPrediction,
      fertileWindowStart: fertileWindowStart ?? _fertileWindowStart,
      fertileWindowEnd: fertileWindowEnd ?? _fertileWindowEnd,
      ovulationDay: ovulationDay ?? _ovulationDay,
      isIrregular: isIrregular ?? this.isIrregular,
      stats: stats ?? this.stats,
      dataMaturity: dataMaturity ?? this.dataMaturity,
      hasData: hasData ?? this.hasData,
      nextPeriodWindowStart:
          nextPeriodWindowStart ?? _nextPeriodWindowStart,
      nextPeriodWindowEnd:
          nextPeriodWindowEnd ?? _nextPeriodWindowEnd,
      pmsWindowStart: pmsWindowStart ?? _pmsWindowStart,
      pmsWindowEnd: pmsWindowEnd ?? _pmsWindowEnd,
      regularityScore: regularityScore ?? this.regularityScore,
      trendPoints: trendPoints ?? this.trendPoints,
      regularityLevel: regularityLevel ?? this.regularityLevel,
      disclaimerCode: disclaimerCode ?? this.disclaimerCode,
      regularityLabel: regularityLabel ?? _regularityLabel,
      predictionDisclaimer:
          predictionDisclaimer ?? _predictionDisclaimer,
      isOverdue: isOverdue ?? this.isOverdue,
      daysOverdue: daysOverdue ?? this.daysOverdue,
      missedCycles: missedCycles ?? this.missedCycles,
      needsUserAttention:
          needsUserAttention ?? this.needsUserAttention,
      hasPhaseConflict: hasPhaseConflict ?? this.hasPhaseConflict,
      hasImplausiblePeriodData:
          hasImplausiblePeriodData ?? this.hasImplausiblePeriodData,
      isProjected: isProjected ?? this.isProjected,
      discardedOutliers: discardedOutliers ?? this.discardedOutliers,
      cycleLengthSd: cycleLengthSd ?? this.cycleLengthSd,
      forecastAnchor: forecastAnchor ?? this.forecastAnchor,
      forecast: forecast ?? this.forecast,
      isBleedingConfirmed:
          isBleedingConfirmed ?? this.isBleedingConfirmed,
      isOpenPeriodBeyondAverage:
          isOpenPeriodBeyondAverage ?? this.isOpenPeriodBeyondAverage,
      openPeriodDayCount:
          openPeriodDayCount ?? this.openPeriodDayCount,
      actualPeriodStart: actualPeriodStart ?? this.actualPeriodStart,
      isStartDueToday: isStartDueToday ?? this.isStartDueToday,
      missedExpectedStarts:
          missedExpectedStarts ?? this.missedExpectedStarts,
      awaitingStartConfirmation:
          awaitingStartConfirmation ?? this.awaitingStartConfirmation,
      awaitingEndConfirmation:
          awaitingEndConfirmation ?? this.awaitingEndConfirmation,
    );
  }
}

class CycleEngine implements CachedEngine<CycleEngineInput, CycleEngineOutput> {
  static const int minPlausibleCycle = CycleSettings.minCycleLength;
  static const int maxPlausibleCycle = CycleSettings.maxCycleLength;
  static const int maxPlausiblePeriodDays =
      CycleSettings.maxPlausiblePeriodDays;

  // Horizon constraints (F-15)
  static const int defaultHorizonCycles = 12;
  static const int maxHorizonCycles = 24;

  // Uncertainty & Confidence Model constants (F-10, F-11)
  static const double _minSigmaDays = 0.5;
  static const double _maxSigmaDays = 12.0;
  static const double _fallbackSigmaDays = 3.5;
  static const double _distanceDampingRate = 0.18;
  static const double _highConfidenceThreshold = 0.66;
  static const double _mediumConfidenceThreshold = 0.38;

  @override
  Future<CycleEngineOutput> calculate(CycleEngineInput input) async {
    final db = input.db;
    final appSettings = input.appSettings;
    final now = CycleDateContract.cleanDate(input.now);

    final isFemale = CyclePrivacyGuard.isVisible(appSettings);
    final cycleEnabled = ModuleGate.instance.isEnabledFrom(
      appSettings,
      'module_cycle_enabled',
    );

    if (!isFemale || !cycleEnabled) {
      return _emptyOutput(now);
    }

    final isPregnancy = CycleSettings.isPregnancyMode(appSettings);
    if (isPregnancy) {
      return _pregnancyOutput(now);
    }

    // 1. Fetch cycle_periods from database (excluding predicted placeholders)
    final List<Map<String, dynamic>> periodRows = await db.query(
      'cycle_periods',
      where: 'isPredicted = 0 OR isPredicted IS NULL',
      orderBy: 'startDate ASC',
    );

    if (periodRows.isEmpty) {
      return _emptyOutput(now);
    }

    final cleanNow = CycleDateContract.cleanDate(now);

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
      final start1 = CycleDateContract.parseDayKey(
        periodRows[i]['startDate']?.toString(),
      );
      final start2 = CycleDateContract.parseDayKey(
        periodRows[i + 1]['startDate']?.toString(),
      );
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
      avgCycleLength =
          cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
    }

    // Average period duration (excluding auto-closed periods)
    final periodDurations = <int>[];
    for (final row in periodRows) {
      final isAutoClosed = (row['autoClosed'] as int? ?? 0) == 1;
      if (isAutoClosed) continue;
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
      avgPeriodDuration =
          periodDurations.reduce((a, b) => a + b) / periodDurations.length;
    }

    // Safe clamped configurations
    final L = avgCycleLength.round().clamp(
      CycleSettings.minCycleLength,
      CycleSettings.maxCycleLength,
    );
    final pDuration = avgPeriodDuration.round().clamp(
      CycleSettings.minPeriodDuration,
      CycleSettings.maxPeriodDuration,
    );

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
      final start =
          CycleDateContract.parseDayKey(
            periodRows[i]['startDate']?.toString(),
          ) ??
          now;
      final end = CycleDateContract.parseDayKey(
        periodRows[i]['endDate']?.toString(),
      );
      var pDays = pDuration;
      if (end != null) {
        pDays = CycleDateContract.daysBetween(start, end) + 1;
      } else {
        final elapsed = CycleDateContract.daysBetween(start, cleanNow) + 1;
        pDays = math.min(elapsed, maxPlausiblePeriodDays);
      }

      var lenDays = L;
      var isInProgress = false;
      if (i < periodRows.length - 1) {
        final nextStart = CycleDateContract.parseDayKey(
          periodRows[i + 1]['startDate']?.toString(),
        );
        if (nextStart != null) {
          lenDays = CycleDateContract.daysBetween(start, nextStart);
        }
      } else {
        lenDays = CycleDateContract.daysBetween(start, cleanNow) + 1;
        isInProgress = true;
      }

      trendPoints.add(
        CycleTrendPoint(
          index: i + 1,
          lengthDays: lenDays,
          periodDays: pDays,
          isInProgress: isInProgress,
        ),
      );
    }

    final pmsWindowDays =
        int.tryParse(appSettings[CycleSettings.keyPmsWindowDays] ?? '4') ??
        CycleSettings.defaultPmsWindowDays;

    final stats = CycleStats(
      avgCycleLength: avgCycleLength,
      avgPeriodDuration: avgPeriodDuration,
      recordedPeriods: recordedPeriods,
      completedCycles: completedCycles,
    );

    final actualAnchorStart = CycleDateContract.parseDayKey(
      periodRows.last['startDate']?.toString(),
    );

    // 7. Find current status based on target date `now`
    Map<String, dynamic>? currentPeriodRow;
    for (var i = periodRows.length - 1; i >= 0; i--) {
      final start = CycleDateContract.parseDayKey(
        periodRows[i]['startDate']?.toString(),
      );
      if (start != null && CycleDateContract.isSameOrBefore(start, now)) {
        currentPeriodRow = periodRows[i];
        break;
      }
    }

    if (currentPeriodRow == null) {
      final firstStart =
          CycleDateContract.parseDayKey(
            periodRows.first['startDate']?.toString(),
          ) ??
          now;
      final daysDiff = CycleDateContract.daysBetween(now, firstStart);
      final cyclesToSubtract = (daysDiff / L).ceil();
      final estimatedPrevStart = firstStart.subtract(
        Duration(days: cyclesToSubtract * L),
      );

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
        anchorStart: actualAnchorStart ?? firstStart,
        horizonCycles: input.horizonCycles,
      );
    }

    final currentPeriodStart =
        CycleDateContract.parseDayKey(
          currentPeriodRow['startDate']?.toString(),
        ) ??
        now;
    final currentPeriodEnd = CycleDateContract.parseDayKey(
      currentPeriodRow['endDate']?.toString(),
    );

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
      anchorStart: actualAnchorStart ?? currentPeriodStart,
      horizonCycles: input.horizonCycles,
    );
  }

  static CycleRegularity _computeRegularity(List<int> cycleLengths) {
    final n = cycleLengths.length;
    if (n < CycleSettings.minCyclesForReliableForecast) {
      return CycleRegularity(
        score: null,
        level: RegularityLevel.insufficientData,
        isIrregular: false,
        sampleSize: n,
        isComputable: false,
      );
    }

    final mean = cycleLengths.reduce((a, b) => a + b) / n;
    final variance =
        cycleLengths.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) /
        (n > 1 ? (n - 1) : 1);
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
      sdDays: sd,
    );
  }

  /// Pure multi-cycle forecast builder (F-08..F-17)
  @visibleForTesting
  static List<PredictedCycle> buildForecast({
    required DateTime anchorStart, // آخرین شروع دورهٔ واقعی
    required int cycleLength, // L
    required int periodDays, // pDuration
    required int lutealDays, // lutealDays clamped
    required int pmsWindowDays, // pmsWindowDays
    required double? sdDays, // null => قابل محاسبه نیست
    required int completedCycles,
    required int? regularityScore,
    required String dataMaturity, // LOW / MEDIUM / HIGH
    required int discardedOutliers,
    required int horizonCycles,
    required DateTime now,
    bool isDelayedOrStale = false,
  }) {
    final cleanNow = CycleDateContract.cleanDate(now);
    final cleanAnchor = CycleDateContract.cleanDate(anchorStart);
    final daysSinceAnchor = CycleDateContract.daysBetween(
      cleanAnchor,
      cleanNow,
    );

    var firstK = (daysSinceAnchor / cycleLength).ceil();
    if (firstK < 1) firstK = 1;

    final effectiveHorizon = isDelayedOrStale
        ? math.min(3, horizonCycles)
        : horizonCycles;

    // 1) Regularity factor (F-11)
    final double regularityFactor = (regularityScore == null)
        ? 0.35
        : (regularityScore / 100.0);

    // 2) Data maturity factor (F-11)
    final double maturityFactor = switch (dataMaturity.toUpperCase()) {
      'HIGH' || 'ESTABLISHED' => 1.0,
      'MEDIUM' => 0.8,
      _ => 0.55,
    };

    // 3) Noise penalty (F-11)
    final double noisePenalty = (discardedOutliers == 0)
        ? 1.0
        : (1.0 - (discardedOutliers * 0.06)).clamp(0.6, 1.0);

    final double baseConfidence =
        (regularityFactor * maturityFactor * noisePenalty).clamp(0.0, 1.0);

    final basis = completedCycles >= CycleSettings.minCyclesForReliableForecast
        ? ForecastBasis.measured
        : (completedCycles >= 1
              ? ForecastBasis.partiallyMeasured
              : ForecastBasis.defaultAssumption);

    double sigmaFor(int k) {
      final base = (sdDays == null || sdDays <= 0)
          ? _fallbackSigmaDays
          : sdDays;
      var raw = base * math.sqrt(k);
      if (isDelayedOrStale) {
        raw *= 1.5;
      }
      return raw.clamp(_minSigmaDays, _maxSigmaDays);
    }

    final out = <PredictedCycle>[];
    for (var i = 0; i < effectiveHorizon; i++) {
      final k = firstK + i;
      final start = cleanAnchor.add(Duration(days: k * cycleLength));
      final end = start.add(Duration(days: periodDays - 1));
      final sigma = sigmaFor(k);
      final sigmaRounded = sigma.round();
      final winStart = start.subtract(Duration(days: sigmaRounded));
      final winEnd = start.add(Duration(days: sigmaRounded));

      var confidence = (baseConfidence / (1.0 + _distanceDampingRate * (k - 1)))
          .clamp(0.0, 1.0);
      if (isDelayedOrStale) {
        confidence = math.min(confidence, 0.35);
      }

      final PredictionConfidenceLevel confidenceLevel;
      if (isDelayedOrStale || basis != ForecastBasis.measured) {
        confidenceLevel = PredictionConfidenceLevel.low;
      } else {
        if (confidence >= _highConfidenceThreshold) {
          confidenceLevel = PredictionConfidenceLevel.high;
        } else if (confidence >= _mediumConfidenceThreshold) {
          confidenceLevel = PredictionConfidenceLevel.medium;
        } else {
          confidenceLevel = PredictionConfidenceLevel.low;
        }
      }

      final ovulation = start.subtract(Duration(days: lutealDays));
      final fertileStart = ovulation.subtract(const Duration(days: 5));
      final fertileEnd = ovulation.add(const Duration(days: 1));

      final pmsStart = start.subtract(Duration(days: pmsWindowDays));
      final pmsEnd = start.subtract(const Duration(days: 1));

      out.add(
        PredictedCycle(
          index: i + 1,
          predictedStart: start,
          predictedEnd: end,
          windowStart: winStart,
          windowEnd: winEnd,
          sigmaDays: sigma,
          periodDays: periodDays,
          confidence: confidence,
          confidenceLevel: confidenceLevel,
          basis: basis,
          ovulationDay: ovulation,
          fertileStart: fertileStart,
          fertileEnd: fertileEnd,
          pmsStart: pmsStart,
          pmsEnd: pmsEnd,
        ),
      );
    }

    return out;
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
    DateTime? anchorStart,
    int horizonCycles = defaultHorizonCycles,
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
    var isBleedingConfirmed = false;
    var isOpenPeriodBeyondAverage = false;
    var openPeriodDayCount = 0;
    var awaitingEndConfirmation = false;

    if (daysSinceStart >= 0) {
      if (endDate != null) {
        final cleanEnd = CycleDateContract.cleanDate(endDate);
        if (CycleDateContract.isSameOrBefore(cleanNow, cleanEnd)) {
          isBleeding = true;
          dayOfPeriod = daysSinceStart + 1;
          isBleedingConfirmed = !isProjected;
        }
      } else {
        // دورهٔ باز: تا تأیید کاربر، وضعیت واقعی «در جریان» است.
        // قبلاً از میانگین pDuration استفاده می‌شد و همین باعث می‌شد UI
        // بی‌اجازه فاز را به فولیکولار ببرد در حالی که رکورد هنوز باز بود.
        if (daysSinceStart < maxPlausiblePeriodDays) {
          isBleeding = true;
          dayOfPeriod = daysSinceStart + 1;
          openPeriodDayCount = daysSinceStart + 1;
          isOpenPeriodBeyondAverage = daysSinceStart >= pDuration;
          awaitingEndConfirmation =
              daysSinceStart >=
              pDuration + CycleSettings.prolongedBleedingGraceDays;
          isBleedingConfirmed = !isProjected;
        } else {
          hasImplausiblePeriodData = true;
          dayOfPeriod = maxPlausiblePeriodDays;
          openPeriodDayCount = maxPlausiblePeriodDays;
          awaitingEndConfirmation = true;
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

    // Overdue tracking (C-18, Bug 7 fix)
    final missedCycles = (daysSinceStart / L).floor();
    final isStartDueToday = !isBleeding && daysSinceStart == L;
    final isOverdue = !isBleeding && daysSinceStart > L;
    final daysOverdue = (!isBleeding && daysSinceStart > L)
        ? (daysSinceStart - L)
        : 0;
    final awaitingStartConfirmation = !isBleeding && daysSinceStart >= L;
    final needsUserAttention =
        (!isBleeding && (missedCycles >= 2 || daysOverdue >= 45));

    // Missed expected starts tracking (Section 3.2 Fix 3)
    final missedExpectedStarts = <DateTime>[];
    if (!isBleeding && daysSinceStart >= L) {
      final totalMissed = (daysSinceStart / L).floor();
      for (var k = 1; k <= totalMissed; k++) {
        final missedDate = cleanStart.add(Duration(days: k * L));
        if (CycleDateContract.isSameOrBefore(missedDate, cleanNow)) {
          missedExpectedStarts.add(missedDate);
        }
      }
      if (missedExpectedStarts.length > 6) {
        missedExpectedStarts.removeRange(0, missedExpectedStarts.length - 6);
      }
    }

    // Phase determination (Section 3.3)
    final currentDayInCycle = isStartDueToday ? L : ((daysSinceStart % L) + 1);
    CyclePhase phase;
    if (needsUserAttention) {
      phase = CyclePhase.dataStale;
    } else if (isBleeding) {
      phase = CyclePhase.menstrual;
    } else if (isOverdue) {
      // فقط زمانی که موعد گذشته و کاربر چیزی ثبت نکرده (daysSinceStart > L):
      phase = CyclePhase.dataStale;
    } else {
      final ovulationDayNum = L - lutealDays;
      if (currentDayInCycle < ovulationDayNum - 1) {
        phase = CyclePhase.follicular;
      } else if (currentDayInCycle >= ovulationDayNum - 1 &&
          currentDayInCycle <= ovulationDayNum + 1) {
        phase = CyclePhase.ovulation;
      } else {
        phase = CyclePhase.luteal;
      }
    }

    // C-19: Phase conflict check
    final hasPhaseConflict =
        isBleeding && currentDayInCycle >= (L - lutealDays - 1);

    final effectiveAnchor = anchorStart ?? startDate;

    final forecast = buildForecast(
      anchorStart: effectiveAnchor,
      cycleLength: L,
      periodDays: pDuration,
      lutealDays: lutealDays,
      pmsWindowDays: pmsWindowDays,
      sdDays: regularity.sdDays,
      completedCycles: stats.completedCycles,
      regularityScore: regularity.score,
      dataMaturity: dataMaturity,
      discardedOutliers: discardedOutliers,
      horizonCycles: horizonCycles,
      now: cleanNow,
      isDelayedOrStale: needsUserAttention,
    );

    return CycleEngineOutput(
      currentPhase: phase,
      dayOfCycle: dayOfCycle,
      dayOfPeriod: dayOfPeriod,
      isIrregular: regularity.isIrregular,
      stats: stats,
      dataMaturity: dataMaturity,
      hasData: true,
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
      cycleLengthSd: regularity.sdDays,
      forecastAnchor: effectiveAnchor,
      forecast: forecast,
      isBleedingConfirmed: isBleedingConfirmed,
      isOpenPeriodBeyondAverage: isOpenPeriodBeyondAverage,
      openPeriodDayCount: openPeriodDayCount,
      actualPeriodStart: isProjected ? null : startDate,
      isStartDueToday: isStartDueToday,
      missedExpectedStarts: missedExpectedStarts,
      awaitingStartConfirmation: awaitingStartConfirmation,
      awaitingEndConfirmation: awaitingEndConfirmation,
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
    DateTime? anchorStart,
    int horizonCycles = defaultHorizonCycles,
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
      anchorStart: anchorStart,
      horizonCycles: horizonCycles,
    );
  }

  CycleEngineOutput pregnancyOutputForTesting(DateTime now) =>
      _pregnancyOutput(now);

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
      stats: CycleStats(
        avgCycleLength: 28,
        avgPeriodDuration: 6,
        recordedPeriods: 0,
        completedCycles: 0,
      ),
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
      cycleLengthSd: null,
      forecastAnchor: null,
      forecast: const [],
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
      stats: CycleStats(
        avgCycleLength: 28,
        avgPeriodDuration: 6,
        recordedPeriods: 0,
        completedCycles: 0,
      ),
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
      cycleLengthSd: null,
      forecastAnchor: null,
      forecast: const [],
    );
  }

  @override
  Duration get ttl => const Duration(minutes: 60);

  @override
  String fingerprint(CycleEngineInput input) {
    final dayStamp = CycleDateContract.toDayKey(input.now);
    final cycleLen = CycleSettings.getCycleLength(input.appSettings);
    final periodDur = CycleSettings.getPeriodDuration(input.appSettings);
    final luteal = CycleSettings.getLutealPhase(input.appSettings);
    final pmsWindow =
        input.appSettings[CycleSettings.keyPmsWindowDays] ??
        CycleSettings.defaultPmsWindowDays.toString();
    final isPregnancy = CycleSettings.isPregnancyMode(input.appSettings);
    final horizon = input.horizonCycles;
    return '$dayStamp|$cycleLen|$periodDur|$luteal|$pmsWindow|$isPregnancy|$horizon';
  }

  @override
  void invalidate() {
    try {
      RitmoEngineBus.instance.invalidate(CycleEngine);
    } catch (e, st) {
      RitmoLog.error('CycleEngine', 'Failed to invalidate cache: $e', e, st);
    }
  }

  @override
  bool canRun(CycleEngineInput input) {
    final isFemale = CyclePrivacyGuard.isVisible(input.appSettings);
    final cycleEnabled = ModuleGate.instance.isEnabledFrom(
      input.appSettings,
      'module_cycle_enabled',
    );
    return isFemale && cycleEnabled;
  }

  @override
  List<Type> dependencies() => [];

  /// F-08..F-17: Pure static computation of multi-cycle forecasts for testing and external consumers.
  @visibleForTesting
  static List<PredictedCycle> computeMultiCycleForecast({
    required DateTime lastPeriodStart,
    required double avgCycleLength,
    required double avgPeriodDuration,
    double? cycleStdDev,
    String dataMaturity = 'HIGH',
    Map<String, String> settings = const {},
    int horizonCycles = 12,
    DateTime? now,
    int completedCycles = 5,
    double? regularityScore = 85.0,
    bool isDelayedOrStale = false,
  }) {
    final effectiveNow = now ?? lastPeriodStart;
    final cleanAnchor = CycleDateContract.cleanDate(lastPeriodStart);
    final pmsWindowDays = int.tryParse(settings[CycleSettings.keyPmsWindowDays] ?? '4') ??
        CycleSettings.defaultPmsWindowDays;
    final lutealDays = CycleSettings.getLutealPhase(settings);

    return buildForecast(
      anchorStart: cleanAnchor,
      now: effectiveNow,
      cycleLength: avgCycleLength.round(),
      periodDays: avgPeriodDuration.round(),
      sdDays: cycleStdDev,
      regularityScore: regularityScore?.round(),
      dataMaturity: dataMaturity,
      discardedOutliers: 0,
      completedCycles: completedCycles,
      horizonCycles: horizonCycles,
      isDelayedOrStale: isDelayedOrStale,
      lutealDays: lutealDays,
      pmsWindowDays: pmsWindowDays,
    );
  }

  /// F-06: Static fingerprint computation helper for testing.
  @visibleForTesting
  static String computeInputFingerprint({
    required Map<String, String> settings,
    required DateTime now,
    int horizonCycles = 12,
  }) {
    final dayStamp = CycleDateContract.toDayKey(now);
    final cycleLen = CycleSettings.getCycleLength(settings);
    final periodDur = CycleSettings.getPeriodDuration(settings);
    final luteal = CycleSettings.getLutealPhase(settings);
    final pmsWindow = settings[CycleSettings.keyPmsWindowDays] ??
        CycleSettings.defaultPmsWindowDays.toString();
    final isPregnancy = CycleSettings.isPregnancyMode(settings);
    return '$dayStamp|$cycleLen|$periodDur|$luteal|$pmsWindow|$isPregnancy|$horizonCycles';
  }
}
