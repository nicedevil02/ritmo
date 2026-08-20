import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
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
    // Step 0: Method Selection, Step 1: Date Entry, Step 2: HighRisk/Multiple, Step 3: Tone/Unit, Step 4: Reminders, Step 5: Summary
    if (currentStep == 1 || currentStep == 0) {
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

  PregnancyProfile buildProfile() {
    final cleanNow = CycleDateContract.cleanDate(CycleClock.now);
    final effectiveLmp = lmpDate ?? cleanNow;
    final effectiveDue = dueDate ??
        effectiveLmp.add(const Duration(days: PregnancyProfile.gestationTotalDays));

    return PregnancyProfile(
      lmpDate: effectiveLmp,
      dueDate: effectiveDue,
      eddSource: eddSource,
      tone: tone,
      ageUnit: ageUnit,
      isMultiple: isMultiple,
      isHighRisk: isHighRisk,
      reminderHour: reminderHour,
      visitReminderLeadDays: visitLeadDays,
    );
  }

  Future<void> save({DatabaseExecutor? db}) async {
    final executor = db ?? await DatabaseHelper.instance.database;
    final profile = buildProfile();

    if (executor is Database) {
      await executor.transaction((txn) async {
        await PregnancySettings.saveProfile(profile, txn);
        await PregnancySettings.setPregnancyActive(true, db: txn);
        await PregnancySettings.saveSetting(
          PregnancySettings.keySetupDone,
          'true',
          txn,
        );
      });
    } else {
      await PregnancySettings.saveProfile(profile, executor);
      await PregnancySettings.setPregnancyActive(true, db: executor);
      await PregnancySettings.saveSetting(
        PregnancySettings.keySetupDone,
        'true',
        executor,
      );
    }
  }
}
