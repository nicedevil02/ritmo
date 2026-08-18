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
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';

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
    );
  }
}

class CycleStateNotifier extends ValueNotifier<CycleState> {
  CycleStateNotifier() : super(const CycleState()) {
    loadState();
  }

  static final CycleStateNotifier instance = CycleStateNotifier();

  /// Loads full cycle state from database, settings, and calculation engine.
  Future<void> loadState() async {
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

      CycleEngineOutput? engineOutput;
      if (isEligible && isModuleEnabled) {
        final cycleInput = CycleEngineInput(
          db: db,
          appSettings: settingsMap,
          now: CycleClock.now,
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
