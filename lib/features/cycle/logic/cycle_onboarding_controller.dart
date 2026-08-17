// C-13, C-15: CycleOnboardingController
// Clean onboarding coordinator using CycleSettings façade, CycleDateContract, and schema-compliant period records.
import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/services/module_management_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:sqflite/sqflite.dart';

enum CyclePeriodStatusChoice {
  currentlyInPeriod,
  endedWithKnownStart,
  dontKnow,
  currentlyPregnant,
}

class CycleOnboardingData {
  CycleOnboardingData({
    this.periodStatus = CyclePeriodStatusChoice.endedWithKnownStart,
    this.cycleLength = CycleSettings.defaultCycleLength,
    this.periodDuration = CycleSettings.defaultPeriodDuration,
    DateTime? startDate,
    this.worshipConsent = false,
    this.energyConsent = false,
    this.sleepConsent = false,
    this.remindersConsent = false,
    this.dashboardConsent = false,
    this.calendarConsent = false,
    this.enableLock = false,
  }) : startDate = startDate ?? DateTime.now().subtract(const Duration(days: 10));

  CyclePeriodStatusChoice periodStatus;
  int cycleLength;
  int periodDuration;
  DateTime startDate;
  bool worshipConsent;
  bool energyConsent;
  bool sleepConsent;
  bool remindersConsent;
  bool dashboardConsent;
  bool calendarConsent;
  bool enableLock;

  CycleOnboardingData copyWith({
    CyclePeriodStatusChoice? periodStatus,
    int? cycleLength,
    int? periodDuration,
    DateTime? startDate,
    bool? worshipConsent,
    bool? energyConsent,
    bool? sleepConsent,
    bool? remindersConsent,
    bool? dashboardConsent,
    bool? calendarConsent,
    bool? enableLock,
  }) {
    return CycleOnboardingData(
      periodStatus: periodStatus ?? this.periodStatus,
      cycleLength: cycleLength ?? this.cycleLength,
      periodDuration: periodDuration ?? this.periodDuration,
      startDate: startDate ?? this.startDate,
      worshipConsent: worshipConsent ?? this.worshipConsent,
      energyConsent: energyConsent ?? this.energyConsent,
      sleepConsent: sleepConsent ?? this.sleepConsent,
      remindersConsent: remindersConsent ?? this.remindersConsent,
      dashboardConsent: dashboardConsent ?? this.dashboardConsent,
      calendarConsent: calendarConsent ?? this.calendarConsent,
      enableLock: enableLock ?? this.enableLock,
    );
  }
}

class CycleOnboardingController {
  static final CycleOnboardingController instance = CycleOnboardingController._();
  CycleOnboardingController._();

  /// Loads current onboarding configuration if already present (for Edit Mode),
  /// otherwise returns safe default data.
  Future<CycleOnboardingData> loadInitialData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final settingsList = await db.query('app_settings');
      final settingsMap = {
        for (final s in settingsList)
          if (s['key'] != null) s['key'].toString(): s['value']?.toString() ?? ''
      };

      final avgLength = CycleSettings.getCycleLength(settingsMap);
      final avgPeriod = CycleSettings.getPeriodDuration(settingsMap);

      final worship = settingsMap[CycleSettings.keyConsentWorship] == 'true';
      final energy = settingsMap[CycleSettings.keyConsentEnergy] == 'true';
      final sleep = settingsMap[CycleSettings.keyConsentSleep] == 'true';
      final reminders = settingsMap[CycleSettings.keyConsentReminders] == 'true';
      final dashboard = settingsMap[CycleSettings.keyConsentDashboard] == 'true';
      final calendar = settingsMap['show_cycle_in_calendar'] == 'true';

      final hasPin = await CycleLockService.instance.hasCyclePin(db);
      final lockEnabled = CycleSettings.isLockEnabled(settingsMap) && hasPin;

      // Query latest period to infer start date if available
      final periods = await CyclePeriodRepository.instance.getAllPeriods(db);
      DateTime startDate = DateTime.now().subtract(const Duration(days: 10));
      CyclePeriodStatusChoice statusChoice = CyclePeriodStatusChoice.endedWithKnownStart;

      final isPregnant = CycleSettings.isPregnancyMode(settingsMap);
      if (isPregnant) {
        statusChoice = CyclePeriodStatusChoice.currentlyPregnant;
      } else if (periods.isNotEmpty) {
        final p = periods.first;
        startDate = p.startDate;
        if (p.isOpen) {
          statusChoice = CyclePeriodStatusChoice.currentlyInPeriod;
        } else {
          statusChoice = CyclePeriodStatusChoice.endedWithKnownStart;
        }
      }

      return CycleOnboardingData(
        periodStatus: statusChoice,
        cycleLength: avgLength,
        periodDuration: avgPeriod,
        startDate: startDate,
        worshipConsent: worship,
        energyConsent: energy,
        sleepConsent: sleep,
        remindersConsent: reminders,
        dashboardConsent: dashboard,
        calendarConsent: calendar,
        enableLock: lockEnabled,
      );
    } catch (e, st) {
      RitmoLogger.error('[CycleOnboardingController] Error loading initial data', error: e, stack: st);
      return CycleOnboardingData();
    }
  }

  /// Saves onboarding data idempotently into SQLite.
  /// Dual-writes to canonical settings keys, guarantees module enablement,
  /// and calculates exact period end dates without unended period bugs.
  Future<void> saveOnboarding(CycleOnboardingData data, {bool isEditMode = false}) async {
    final db = await DatabaseHelper.instance.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final batch = db.batch();

    // 1. Unconditionally enable cycle module & save setup flags
    final settingsToSave = <String, String>{
      'module_cycle_enabled': 'true',
      'cycle_setup_done': 'true',
      CycleSettings.keyCycleLength: data.cycleLength.toString(),
      CycleSettings.keyPeriodDuration: data.periodDuration.toString(),
      // Mirroring to legacy aliases
      'cycle_avg_length': data.cycleLength.toString(),
      'cycle_avg_period': data.periodDuration.toString(),
      'user_cycle_length': data.cycleLength.toString(),
      'user_period_length': data.periodDuration.toString(),
      // Privacy Consents
      CycleSettings.keyConsentWorship: data.worshipConsent.toString(),
      CycleSettings.keyConsentEnergy: data.energyConsent.toString(),
      CycleSettings.keyConsentSleep: data.sleepConsent.toString(),
      CycleSettings.keyConsentReminders: data.remindersConsent.toString(),
      CycleSettings.keyConsentDashboard: data.dashboardConsent.toString(),
      'show_cycle_in_calendar': data.calendarConsent.toString(),
      'cycle_onboarding_just_completed': 'true',
    };

    final isPregnant = data.periodStatus == CyclePeriodStatusChoice.currentlyPregnant;
    settingsToSave[CycleSettings.keyPregnancyMode] = isPregnant ? 'true' : 'false';
    settingsToSave['pregnancy_mode'] = isPregnant ? 'true' : 'false';

    for (final entry in settingsToSave.entries) {
      batch.insert(
        'app_settings',
        {'key': entry.key, 'value': entry.value, 'updatedAt': nowMs},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 2. Lock Preference
    batch.insert(
      'app_settings',
      {
        'key': CycleSettings.keyLockEnabled,
        'value': data.enableLock ? 'true' : 'false',
        'updatedAt': nowMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 3. Handle Period Insertion / Update idempotently
    final cleanStart = CycleDateContract.cleanDate(data.startDate);
    final cleanStartStr = CycleDateContract.toDayKey(cleanStart);

    if (data.periodStatus == CyclePeriodStatusChoice.currentlyInPeriod) {
      final existing = await db.query(
        'cycle_periods',
        where: 'notes LIKE ? OR startDate = ?',
        whereArgs: ['%ثبت اولیه%', cleanStartStr],
      );

      if (existing.isNotEmpty && isEditMode) {
        batch.update(
          'cycle_periods',
          {
            'startDate': cleanStartStr,
            'endDate': null,
            'periodDuration': null,
            'updatedAt': nowMs,
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else if (existing.isEmpty) {
        batch.insert('cycle_periods', {
          'startDate': cleanStartStr,
          'endDate': null,
          'periodDuration': null,
          'notes': 'ثبت اولیه در راه‌اندازی',
          'suppressedPrayer': 1,
          'fastDebtCreated': 0,
          'createdAt': nowMs,
          'updatedAt': nowMs,
        });
      }
    } else if (data.periodStatus == CyclePeriodStatusChoice.endedWithKnownStart) {
      final calcEndDate = cleanStart.add(Duration(days: data.periodDuration - 1));
      final cleanEndStr = CycleDateContract.toDayKey(calcEndDate);

      final existing = await db.query(
        'cycle_periods',
        where: 'notes LIKE ? OR startDate = ?',
        whereArgs: ['%ثبت اولیه%', cleanStartStr],
      );

      if (existing.isNotEmpty && isEditMode) {
        batch.update(
          'cycle_periods',
          {
            'startDate': cleanStartStr,
            'endDate': cleanEndStr,
            'periodDuration': data.periodDuration,
            'updatedAt': nowMs,
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else if (existing.isEmpty) {
        batch.insert('cycle_periods', {
          'startDate': cleanStartStr,
          'endDate': cleanEndStr,
          'periodDuration': data.periodDuration,
          'notes': 'ثبت اولیه در راه‌اندازی',
          'suppressedPrayer': 1,
          'fastDebtCreated': 0,
          'createdAt': nowMs,
          'updatedAt': nowMs,
        });
      }
    }

    await batch.commit(noResult: true);
    await ModuleManagementService.instance.setModuleEnabled('module_cycle_enabled', true);
    RitmoEvents.notifyRoutineChanged();
  }
}
