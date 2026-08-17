import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/engine_enums.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:sqflite/sqflite.dart';

class FiqhState {
  FiqhState({
    required this.prayerSuspended,
    required this.fastingSuspended,
    required this.qadaTracked,
  });
  final bool prayerSuspended;
  final bool fastingSuspended;
  final bool qadaTracked;
}

class PrivateReminder {
  PrivateReminder({
    required this.level,
    required this.message,
    required this.date,
  });
  final String level; // 'T-7', 'T-3', 'T-1', 'T0'
  final String message;
  final DateTime date;

  Map<String, dynamic> toMap() {
    return {
      'level': level,
      'message': message,
      'date': date.millisecondsSinceEpoch,
    };
  }
}

class HormonalEngineOutput {
  HormonalEngineOutput({
    required this.state,
    required this.dayOfCycle,
    required this.dayOfMenstruation,
    required this.privateReminderQueue,
    required this.fiqhState,
    required this.nextCycleStartDate,
    required this.hasData,
  });
  final HormonalPhase state;
  final int dayOfCycle;
  final int dayOfMenstruation;
  final List<PrivateReminder> privateReminderQueue;
  final FiqhState fiqhState;
  final DateTime nextCycleStartDate;
  final bool hasData;
}

/// Compatibility adapter over [CycleEngine] (Canonical Source of Truth).
/// Deprecated: Direct callers should consume [CycleEngine] or [CycleWorshipPolicy] / [CycleConsentBridge].
@Deprecated('Direct callers should consume CycleEngine or CycleWorshipPolicy / CycleConsentBridge.')
class HormonalIntelligenceEngine {
  static Future<HormonalEngineOutput> evaluate({
    required Database db,
    required Map<String, String> appSettings,
    required DateTime now,
  }) async {
    final cycleEnabled = ModuleGate.instance.isEnabledFrom(appSettings, 'module_cycle_enabled');
    final isFemale = CyclePrivacyGuard.isVisible(appSettings);

    if (!cycleEnabled || !isFemale) {
      return HormonalEngineOutput(
        state: HormonalPhase.disabled,
        dayOfCycle: 0,
        dayOfMenstruation: 0,
        privateReminderQueue: [],
        fiqhState: FiqhState(
          prayerSuspended: false,
          fastingSuspended: false,
          qadaTracked: false,
        ),
        nextCycleStartDate: now.add(const Duration(days: 14)),
        hasData: false,
      );
    }

    final engineOutput = await CycleEngine().calculate(
      CycleEngineInput(db: db, appSettings: appSettings, now: now),
    );

    if (!engineOutput.hasData) {
      return HormonalEngineOutput(
        state: HormonalPhase.noData,
        dayOfCycle: 0,
        dayOfMenstruation: 0,
        privateReminderQueue: [],
        fiqhState: FiqhState(
          prayerSuspended: false,
          fastingSuspended: false,
          qadaTracked: false,
        ),
        nextCycleStartDate: now.add(const Duration(days: 14)),
        hasData: false,
      );
    }

    final isPregnancy = CycleSettings.isPregnancyMode(appSettings);

    final state = isPregnancy
        ? HormonalPhase.normal
        : switch (engineOutput.currentPhase) {
            CyclePhase.menstrual => HormonalPhase.menstrual,
            CyclePhase.follicular => HormonalPhase.postCycle,
            CyclePhase.ovulation => HormonalPhase.normal,
            CyclePhase.luteal => HormonalPhase.preCycle,
            CyclePhase.dataStale => HormonalPhase.noData,
            CyclePhase.pregnancy => HormonalPhase.normal,
            CyclePhase.noData => HormonalPhase.noData,
          };

    // Build real private reminder queue (C-38)
    final reminders = <PrivateReminder>[];
    final nextPeriod = engineOutput.nextPeriodPrediction;
    if (nextPeriod != null && !isPregnancy) {
      reminders.add(
        PrivateReminder(
          level: 'T-7',
          message: 'بررسی الگوی چرخه و آمادگی هفته آینده',
          date: nextPeriod.subtract(const Duration(days: 7)),
        ),
      );
      reminders.add(
        PrivateReminder(
          level: 'T-3',
          message: 'تخمین شروع پنجره تغییرات هورمونی و مراقبت',
          date: nextPeriod.subtract(const Duration(days: 3)),
        ),
      );
      reminders.add(
        PrivateReminder(
          level: 'T-1',
          message: 'آمادگی برای آغاز چرخه جدید و استراحت کافی',
          date: nextPeriod.subtract(const Duration(days: 1)),
        ),
      );
      reminders.add(
        PrivateReminder(
          level: 'T0',
          message: 'آغاز پیش‌بینی‌شده چرخه زیستی',
          date: nextPeriod,
        ),
      );
    }

    // Delegate fiqh state to canonical CycleWorshipPolicy (C-37)
    final isWorshipSuspended = await CycleWorshipPolicy.isWorshipSuspended(
      dbExecutor: db,
      appSettings: appSettings,
      targetDate: now,
    );

    return HormonalEngineOutput(
      state: state,
      dayOfCycle: engineOutput.dayOfCycle,
      dayOfMenstruation: engineOutput.dayOfPeriod,
      privateReminderQueue: reminders,
      fiqhState: FiqhState(
        prayerSuspended: isWorshipSuspended,
        fastingSuspended: isWorshipSuspended,
        qadaTracked: isWorshipSuspended,
      ),
      nextCycleStartDate: engineOutput.nextPeriodPrediction ?? now.add(const Duration(days: 14)),
      hasData: true,
    );
  }
}
