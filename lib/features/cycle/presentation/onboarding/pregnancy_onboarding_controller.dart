import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_contract.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_engine.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';
import 'package:sqflite/sqflite.dart';

class PregnancyOnboardingController extends ChangeNotifier {
  int currentStep = 0;
  DateTime? lmpDate;
  DateTime? dueDate;
  PregnancyEddSource eddSource = PregnancyEddSource.lmp;
  PregnancyTone tone = PregnancyTone.warm;
  PregnancyAgeUnit ageUnit = PregnancyAgeUnit.weeks;
  bool isMultiple = false;
  bool isHighRisk = false;
  int reminderHour = PregnancyProfile.defaultReminderHour;
  int visitLeadDays = PregnancyProfile.defaultVisitReminderLeadDays;
  String? validationErrorFa;

  void nextStep({DateTime? now}) {
    if (validateCurrentStep(now: now)) {
      if (currentStep < 5) {
        currentStep++;
        notifyListeners();
      }
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      currentStep--;
      validationErrorFa = null;
      notifyListeners();
    }
  }

  void setStep(int step) {
    currentStep = step.clamp(0, 5);
    notifyListeners();
  }

  void setEddSource(PregnancyEddSource source) {
    eddSource = source;
    notifyListeners();
  }

  void setLmpDate(DateTime date) {
    final clean = CycleDateContract.cleanDate(date);
    lmpDate = clean;
    dueDate = PregnancyDateEngine.calculateEddFromLmp(clean);
    validationErrorFa = null;
    notifyListeners();
  }

  void setDueDate(DateTime date) {
    final clean = CycleDateContract.cleanDate(date);
    dueDate = clean;
    lmpDate = PregnancyDateEngine.calculateLmpFromEdd(clean);
    validationErrorFa = null;
    notifyListeners();
  }

  void setConceptionDate(DateTime date) {
    final clean = CycleDateContract.cleanDate(date);
    final calculatedDue = PregnancyDateEngine.calculateEddFromConception(clean);
    dueDate = calculatedDue;
    lmpDate = PregnancyDateEngine.calculateLmpFromEdd(calculatedDue);
    validationErrorFa = null;
    notifyListeners();
  }

  void setUltrasound({
    required DateTime date,
    required int crlMm,
  }) {
    final calculatedDue = PregnancyDateEngine.calculateEddFromUltrasound(
      ultrasoundDate: date,
      crownRumpLengthMm: crlMm,
    );
    dueDate = calculatedDue;
    lmpDate = PregnancyDateEngine.calculateLmpFromEdd(calculatedDue);
    validationErrorFa = null;
    notifyListeners();
  }

  void setTone(PregnancyTone t) {
    tone = t;
    notifyListeners();
  }

  void setAgeUnit(PregnancyAgeUnit unit) {
    ageUnit = unit;
    notifyListeners();
  }

  void setMultiple(bool multiple) {
    isMultiple = multiple;
    notifyListeners();
  }

  void setHighRisk(bool highRisk) {
    isHighRisk = highRisk;
    notifyListeners();
  }

  void setReminderHour(int hour) {
    reminderHour = hour;
    notifyListeners();
  }

  void setVisitLeadDays(int days) {
    visitLeadDays = days;
    notifyListeners();
  }

  bool validateCurrentStep({DateTime? now}) {
    // Step 0: Method Selection (always valid)
    // Step 1: Date Entry (validate LMP/EDD range)
    // Steps 2-4: Options and Settings
    if (currentStep == 1) {
      if (lmpDate == null || dueDate == null) {
        validationErrorFa = 'لطفاً تاریخ مربوطه را مشخص کنید.';
        notifyListeners();
        return false;
      }
      final validation = PregnancyDateEngine.validatePregnancyDates(
        lmp: lmpDate!,
        edd: dueDate!,
        now: now,
      );
      if (!validation.isValid) {
        validationErrorFa = validation.errorMessageFa;
        notifyListeners();
        return false;
      }
    }
    validationErrorFa = null;
    notifyListeners();
    return true;
  }

  bool pauseCyclePredictions = true;
  bool suspendWorship = false;
  bool lockEnabled = false;
  bool hideFromDashboard = true;
  bool maskNotifications = true;

  PregnancyOnboardingData buildOnboardingData() {
    return PregnancyOnboardingData(
      tone: tone,
      eddSource: eddSource,
      lmpDate: lmpDate,
      dueDate: dueDate,
      isMultiple: isMultiple,
      isHighRisk: isHighRisk,
      pauseCyclePredictions: pauseCyclePredictions,
      suspendWorship: suspendWorship,
      lockEnabled: lockEnabled,
      hideFromDashboard: hideFromDashboard,
      maskNotifications: maskNotifications,
      ageUnit: ageUnit,
    );
  }

  PregnancyProfile buildProfile([PregnancyOnboardingData? customData]) {
    final d = customData ?? buildOnboardingData();
    final cleanNow = CycleDateContract.cleanDate(CycleClock.now);
    final effectiveLmp = d.lmpDate ?? cleanNow;
    final effectiveDue = d.dueDate ??
        effectiveLmp.add(const Duration(days: PregnancyProfile.gestationTotalDays));

    return PregnancyProfile(
      lmpDate: effectiveLmp,
      dueDate: effectiveDue,
      eddSource: d.eddSource,
      tone: d.tone,
      ageUnit: d.ageUnit,
      isMultiple: d.isMultiple,
      isHighRisk: d.isHighRisk,
      sectionHidden: d.hideFromDashboard,
      maskNotifications: d.maskNotifications,
      lockEnabled: d.lockEnabled,
      reminderHour: reminderHour,
      visitReminderLeadDays: visitLeadDays,
    );
  }

  Future<void> savePregnancyOnboarding(
    PregnancyOnboardingData data, {
    bool isEditMode = false,
    DatabaseExecutor? db,
  }) async {
    final executor = db ?? await DatabaseHelper.instance.database;
    final nowMs = CycleClock.nowMillisecondsSinceEpoch;
    final profile = buildProfile(data);

    Future<void> performAtomicSave(DatabaseExecutor txn) async {
      // 1. Write profile
      await PregnancySettings.saveProfile(profile, txn);

      // 2. Setup done flag
      await PregnancySettings.saveSetting(
        PregnancySettings.keySetupDone,
        'true',
        txn,
      );

      // 3. Set pregnancy active
      await PregnancySettings.setPregnancyActive(true, db: txn);

      // 4. Pause cycle predictions consent
      if (data.pauseCyclePredictions) {
        await PregnancySettings.saveSetting('cycle_consent_reminders', 'false', txn);
      }

      // 5. Suspend worship consent
      if (data.suspendWorship) {
        await PregnancySettings.saveSetting('cycle_consent_worship', 'false', txn);
      }

      // 6. Hide from dashboard consent
      if (data.hideFromDashboard) {
        await PregnancySettings.saveSetting('cycle_consent_dashboard', 'false', txn);
      }

      // 7. Close open cycle period if any
      try {
        final openPeriods = await txn.query(
          CyclePeriodContract.table,
          where: '${CyclePeriodContract.colEndDate} IS NULL OR ${CyclePeriodContract.colEndDate} = ?',
          whereArgs: [''],
        );
        for (final row in openPeriods) {
          final id = row[CyclePeriodContract.colId] as String?;
          final startStr = row[CyclePeriodContract.colStartDate] as String?;
          if (id != null && startStr != null) {
            final start = CycleDateContract.parseDayKey(startStr);
            if (start != null) {
              final defaultEnd = start.add(const Duration(days: 4));
              await txn.update(
                CyclePeriodContract.table,
                {
                  CyclePeriodContract.colEndDate: CycleDateContract.toDayKey(defaultEnd),
                  CyclePeriodContract.colUpdatedAt: nowMs,
                },
                where: '${CyclePeriodContract.colId} = ?',
                whereArgs: [id],
              );
            }
          }
        }
      } catch (e, st) {
        RitmoLogger.warning(
          '[PregnancyOnboardingController] cycle_periods table update bypassed: $e',
          stack: st,
        );
      }
    }

    if (executor is Database) {
      await executor.transaction((txn) async {
        await performAtomicSave(txn);
      });
    } else {
      await performAtomicSave(executor);
    }

    // Post transaction invalidations
    try {
      CycleEngine().invalidate();
    } catch (_) {}

    try {
      RitmoEvents.notifyRoutineChanged();
    } catch (_) {}
  }

  Future<void> save({DatabaseExecutor? db}) async {
    await savePregnancyOnboarding(buildOnboardingData(), db: db);
  }
}
