// CycleCheckinOrchestrator (C-35, C-41: Check-in prompt determination without hardcoded strings)
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';

enum CycleCheckinPromptType {
  forgottenOpenPeriod,
  menstrualActive,
  pmsApproaching,
  encourageDailyLog,
}

class CycleCheckinOrchestrator {
  static CycleCheckinPromptType? determinePrompt({
    required CyclePhase phase,
    required DataQualityReport dataQuality,
    required DateTime? pmsWindowStart,
    required DateTime now,
  }) {
    if (dataQuality.hasForgottenOpenPeriod) {
      return CycleCheckinPromptType.forgottenOpenPeriod;
    }

    if (phase == CyclePhase.menstrual) {
      return CycleCheckinPromptType.menstrualActive;
    }

    if (pmsWindowStart != null) {
      final cleanNow = CycleDateContract.cleanDate(now);
      final cleanPms = CycleDateContract.cleanDate(pmsWindowStart);
      final daysToPms = CycleDateContract.daysBetween(cleanNow, cleanPms);
      if (daysToPms >= 0 && daysToPms <= 3 && !dataQuality.hasRecentDailyLogs) {
        return CycleCheckinPromptType.pmsApproaching;
      }
    }

    if (!dataQuality.hasRecentDailyLogs && dataQuality.hasEnoughCycles) {
      return CycleCheckinPromptType.encourageDailyLog;
    }

    return null;
  }

  static String? checkinPromptFa({
    required CyclePhase phase,
    required DataQualityReport dataQuality,
    required DateTime? pmsWindowStart,
    required DateTime now,
  }) {
    final type = determinePrompt(
      phase: phase,
      dataQuality: dataQuality,
      pmsWindowStart: pmsWindowStart,
      now: now,
    );
    return type?.name;
  }
}
