// C-17, C-18: CycleStateNotifier (ChangeNotifier & ValueNotifier architecture)
// Unified state coordinator for Cycle screen, home widget, and profile integrations.
import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/services/module_management_service.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/features/cycle/logic/cycle_anomaly_detector.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_data_quality_engine.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';
import 'package:ritmo/features/cycle/logic/cycle_personal_pattern_engine.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:ritmo/features/cycle/models/cycle_forecast_models.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';

class CycleState {
  final bool isLoading;
  final bool isEligible; // Female gender check
  final bool isModuleEnabled;
  final bool isLocked;
  final bool isPregnancyMode;
  final bool justFinishedOnboarding;
  final CyclePeriod? activePeriod;
  final List<CyclePeriod> periods;
  final CycleEngineOutput? engineOutput;
  final Map<String, String> settings;
  final String? errorMessage;
  final int horizonCycles;
  final DataQualityReport? dataQuality;
  final List<SymptomForecast> symptomForecasts;
  final List<CycleAnomaly> anomalies;

  const CycleState({
    this.isLoading = true,
    this.isEligible = false,
    this.isModuleEnabled = false,
    this.isLocked = false,
    this.isPregnancyMode = false,
    this.justFinishedOnboarding = false,
    this.activePeriod,
    this.periods = const [],
    this.engineOutput,
    this.settings = const {},
    this.errorMessage,
    this.horizonCycles = CycleEngine.defaultHorizonCycles,
    this.dataQuality,
    this.symptomForecasts = const [],
    this.anomalies = const [],
  });

  CycleState copyWith({
    bool? isLoading,
    bool? isEligible,
    bool? isModuleEnabled,
    bool? isLocked,
    bool? isPregnancyMode,
    bool? justFinishedOnboarding,
    CyclePeriod? activePeriod,
    bool clearActivePeriod = false,
    List<CyclePeriod>? periods,
    CycleEngineOutput? engineOutput,
    Map<String, String>? settings,
    String? errorMessage,
    int? horizonCycles,
    DataQualityReport? dataQuality,
    List<SymptomForecast>? symptomForecasts,
    List<CycleAnomaly>? anomalies,
  }) {
    return CycleState(
      isLoading: isLoading ?? this.isLoading,
      isEligible: isEligible ?? this.isEligible,
      isModuleEnabled: isModuleEnabled ?? this.isModuleEnabled,
      isLocked: isLocked ?? this.isLocked,
      isPregnancyMode: isPregnancyMode ?? this.isPregnancyMode,
      justFinishedOnboarding:
          justFinishedOnboarding ?? this.justFinishedOnboarding,
      activePeriod: clearActivePeriod
          ? null
          : (activePeriod ?? this.activePeriod),
      periods: periods ?? this.periods,
      engineOutput: engineOutput ?? this.engineOutput,
      settings: settings ?? this.settings,
      errorMessage: errorMessage ?? this.errorMessage,
      horizonCycles: horizonCycles ?? this.horizonCycles,
      dataQuality: dataQuality ?? this.dataQuality,
      symptomForecasts: symptomForecasts ?? this.symptomForecasts,
      anomalies: anomalies ?? this.anomalies,
    );
  }
}

class CycleStateNotifier extends ValueNotifier<CycleState> {
  CycleStateNotifier() : super(const CycleState()) {
    loadState();
  }

  static final CycleStateNotifier instance = CycleStateNotifier();

  /// F-18: Ensures that the forecast covers [lastVisibleDay].
  /// If the current forecast already reaches [lastVisibleDay], does nothing (zero recomputation).
  Future<void> ensureHorizonCovers(DateTime lastVisibleDay) async {
    final currentForecast = value.engineOutput?.forecast ?? const [];
    if (currentForecast.isEmpty) return;

    final lastEnd = currentForecast.last.predictedEnd;
    if (!lastVisibleDay.isAfter(lastEnd)) {
      return;
    }

    final anchor = value.engineOutput?.forecastAnchor ?? CycleClock.now;
    final daysDiff = CycleDateContract.daysBetween(anchor, lastVisibleDay);
    final avgL = (value.engineOutput?.stats.avgCycleLength ?? 28).round().clamp(
      21,
      45,
    );
    final neededCycles = (daysDiff / avgL).ceil() + 2;
    final newHorizon = neededCycles.clamp(
      CycleEngine.defaultHorizonCycles,
      CycleEngine.maxHorizonCycles,
    );

    if (newHorizon > value.horizonCycles) {
      CycleEngine().invalidate();
      await loadState(horizonCycles: newHorizon);
    }
  }

  /// Loads full cycle state from database, settings, and calculation engine.
  Future<void> loadState({int? horizonCycles}) async {
    final effectiveHorizon = horizonCycles ?? value.horizonCycles;
    value = value.copyWith(isLoading: true, errorMessage: null);
    try {
      final db = await DatabaseHelper.instance.database;
      final settingsList = await db.query('app_settings');
      final settingsMap = {
        for (final s in settingsList)
          if (s['key'] != null)
            s['key'].toString(): s['value']?.toString() ?? '',
      };

      final isEligible = CyclePrivacyGuard.isVisible(settingsMap);
      final isModuleEnabled = ModuleGate.instance.isEnabledFrom(
        settingsMap,
        'module_cycle_enabled',
      );
      final isPregnancy = CycleSettings.isPregnancyMode(settingsMap);
      final isLockConfigured = CycleSettings.isLockEnabled(settingsMap);
      final hasPin = await CycleLockService.instance.hasCyclePin(db);
      final isLocked = isLockConfigured && hasPin;
      final justOnboarded =
          settingsMap['cycle_onboarding_just_completed'] == 'true';

      final periods = await CyclePeriodRepository.instance.getAllPeriods(db);
      final active = await CyclePeriodRepository.instance.getActivePeriod(db);
      final periodRows = await db.query(
        'cycle_periods',
        orderBy: 'startDate ASC',
      );

      DataQualityReport? dataQuality;
      List<SymptomForecast> symptomForecasts = const [];
      List<CycleAnomaly> anomalies = const [];

      CycleEngineOutput? engineOutput;
      if (isEligible && isModuleEnabled) {
        final now = CycleClock.now;

        // F-20: Data quality evaluation
        dataQuality = await CycleDataQualityEngine.evaluateDataQuality(
          db: db,
          periodRows: periodRows,
          now: now,
        );

        final cycleInput = CycleEngineInput(
          db: db,
          appSettings: settingsMap,
          now: now,
          horizonCycles: effectiveHorizon,
        );

        try {
          engineOutput = await RitmoEngineBus.instance
              .execute<CycleEngineInput, CycleEngineOutput>(
                CycleEngine,
                cycleInput,
              );
        } catch (e, st) {
          RitmoLogger.error(
            '[CycleStateNotifier] Engine bus execution failed, falling back to direct calculation: $e',
            error: e,
            stack: st,
          );
          final fallbackEngine = CycleEngine();
          engineOutput = await fallbackEngine.calculate(cycleInput);
        }

        // F-21: Anomaly detection
        anomalies = CycleAnomalyDetector.detectAnomalies(
          periodRows: periodRows,
          avgCycleLength: engineOutput.stats.avgCycleLength,
          engineOutput: engineOutput,
          now: now,
        );

        // F-22: Personal pattern forecasting
        if (engineOutput.stats.avgCycleLength > 0) {
          symptomForecasts =
              await CyclePersonalPatternEngine.computePersonalForecasts(
                db: db,
                periodRows: periodRows,
                avgCycleLength: engineOutput.stats.avgCycleLength,
                now: now,
              );
        }

        // F-20 & F-21: Quality & Anomaly adjustments to engineOutput.forecast
        if (engineOutput.forecast.isNotEmpty) {
          final hasForgottenOpen = dataQuality.hasForgottenOpenPeriod;
          final hasConsultClinician = anomalies.any(
            (a) => a.severity == CycleAnomalySeverity.consultClinician,
          );
          final hasVariability = anomalies.any(
            (a) =>
                a.type == CycleAnomalyType.highVariabilityTrend ||
                a.type == CycleAnomalyType.abnormallyShortCycle ||
                a.type == CycleAnomalyType.abnormallyLongCycle,
          );

          if (hasForgottenOpen || hasConsultClinician || hasVariability) {
            final adjustedForecast = <PredictedCycle>[];
            for (final cycle in engineOutput.forecast) {
              var level = cycle.confidenceLevel;
              var sigma = cycle.sigmaDays;
              if (hasForgottenOpen) {
                level = PredictionConfidenceLevel.low;
              } else if (hasConsultClinician &&
                  level == PredictionConfidenceLevel.high) {
                level = PredictionConfidenceLevel.medium;
              }
              if (hasVariability) {
                sigma = (sigma * 1.25).clamp(0.5, 12.0);
              }
              final sigmaRounded = sigma.round();
              final winStart = cycle.predictedStart.subtract(
                Duration(days: sigmaRounded),
              );
              final winEnd = cycle.predictedStart.add(
                Duration(days: sigmaRounded),
              );

              adjustedForecast.add(
                PredictedCycle(
                  index: cycle.index,
                  predictedStart: cycle.predictedStart,
                  predictedEnd: cycle.predictedEnd,
                  windowStart: winStart,
                  windowEnd: winEnd,
                  sigmaDays: sigma,
                  periodDays: cycle.periodDays,
                  confidence: cycle.confidence,
                  confidenceLevel: level,
                  basis: cycle.basis,
                  ovulationDay: cycle.ovulationDay,
                  fertileStart: cycle.fertileStart,
                  fertileEnd: cycle.fertileEnd,
                  pmsStart: cycle.pmsStart,
                  pmsEnd: cycle.pmsEnd,
                ),
              );
            }

            engineOutput = CycleEngineOutput(
              currentPhase: engineOutput.currentPhase,
              dayOfCycle: engineOutput.dayOfCycle,
              dayOfPeriod: engineOutput.dayOfPeriod,
              isIrregular: engineOutput.isIrregular,
              stats: engineOutput.stats,
              dataMaturity: engineOutput.dataMaturity,
              hasData: engineOutput.hasData,
              regularityScore: engineOutput.regularityScore,
              trendPoints: engineOutput.trendPoints,
              regularityLevel: engineOutput.regularityLevel,
              disclaimerCode: engineOutput.disclaimerCode,
              isOverdue: engineOutput.isOverdue,
              daysOverdue: engineOutput.daysOverdue,
              missedCycles: engineOutput.missedCycles,
              needsUserAttention: engineOutput.needsUserAttention,
              hasPhaseConflict: engineOutput.hasPhaseConflict,
              hasImplausiblePeriodData: engineOutput.hasImplausiblePeriodData,
              isProjected: engineOutput.isProjected,
              discardedOutliers: engineOutput.discardedOutliers,
              cycleLengthSd: engineOutput.cycleLengthSd,
              forecastAnchor: engineOutput.forecastAnchor,
              forecast: adjustedForecast,
            );
          }
        }
      }

      value = CycleState(
        isLoading: false,
        isEligible: isEligible,
        isModuleEnabled: isModuleEnabled,
        isLocked: isLocked,
        isPregnancyMode: isPregnancy,
        justFinishedOnboarding: justOnboarded,
        activePeriod: active,
        periods: periods,
        engineOutput: engineOutput,
        settings: settingsMap,
        horizonCycles: effectiveHorizon,
        dataQuality: dataQuality,
        symptomForecasts: symptomForecasts,
        anomalies: anomalies,
      );
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleStateNotifier] Error loading state',
        error: e,
        stack: st,
      );
      value = value.copyWith(
        isLoading: false,
        errorMessage: 'error_loading_cycle_state',
      );
    }
  }

  /// Starts bleeding period for [startDate] (defaults to today).
  Future<void> startPeriod({DateTime? startDate}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final targetDate = startDate ?? CycleClock.now;
      await CyclePeriodRepository.instance.startPeriod(
        targetDate,
        dbExecutor: db,
      );
      RitmoEventBus().fire(
        RitmoEvent(
          type: 'CycleStarted',
          payload: {'date': targetDate.toIso8601String()},
        ),
      );
      CycleEngine().invalidate();
      await loadState();
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleStateNotifier] startPeriod error',
        error: e,
        stack: st,
      );
    }
  }

  /// Ends currently active bleeding period on [endDate] (defaults to today).
  Future<void> endPeriod({DateTime? endDate}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final active =
          value.activePeriod ??
          await CyclePeriodRepository.instance.getActivePeriod(db);
      if (active != null && active.id != null) {
        final targetDate = endDate ?? CycleClock.now;
        await CyclePeriodRepository.instance.endPeriod(
          active.id!,
          targetDate,
          dbExecutor: db,
        );
        RitmoEventBus().fire(
          RitmoEvent(
            type: 'CycleEnded',
            payload: {'date': targetDate.toIso8601String()},
          ),
        );
        CycleEngine().invalidate();
        await loadState();
      }
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleStateNotifier] endPeriod error',
        error: e,
        stack: st,
      );
    }
  }

  /// Deletes a cycle period by [id].
  Future<void> deletePeriod(int id) async {
    try {
      await CyclePeriodRepository.instance.deletePeriod(id);
      RitmoEventBus().fire(
        RitmoEvent(type: 'CycleUpdated', payload: {'deletedId': id}),
      );
      CycleEngine().invalidate();
      await loadState();
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleStateNotifier] deletePeriod error',
        error: e,
        stack: st,
      );
    }
  }

  /// Dismisses one-time onboarding guidance banner (C-18).
  Future<void> dismissOnboardingBanner() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['cycle_onboarding_just_completed'],
      );
      value = value.copyWith(justFinishedOnboarding: false);
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleStateNotifier] dismissOnboardingBanner error',
        error: e,
        stack: st,
      );
    }
  }

  /// Toggles cycle module enabled/disabled state.
  Future<void> toggleModule(bool enabled) async {
    try {
      await ModuleManagementService.instance.setModuleEnabled(
        'module_cycle_enabled',
        enabled,
      );
      RitmoEventBus().fire(
        RitmoEvent(
          type: 'SettingsChanged',
          payload: {'module_cycle_enabled': enabled},
        ),
      );
      CycleEngine().invalidate();
      await loadState();
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleStateNotifier] toggleModule error',
        error: e,
        stack: st,
      );
    }
  }
}
