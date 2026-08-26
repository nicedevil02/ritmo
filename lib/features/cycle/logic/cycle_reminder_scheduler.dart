// C-39: CycleReminderScheduler
// Orchestrator that re-computes and reschedules cycle notifications whenever periods,
// consent settings, or cycle profile configurations are modified.
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/services/cycle_notification_service.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:ritmo/features/cycle/models/cycle_forecast_models.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:sqflite/sqflite.dart';

class CycleReminderScheduler {
  const CycleReminderScheduler._();

  /// Re-evaluates cycle predictions and reschedules notifications across all lookahead cycles.
  static Future<void> rescheduleAll({
    DatabaseExecutor? dbExecutor,
    Map<String, String>? appSettings,
    DateTime? now,
  }) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;

      late final Map<String, String> settings;
      if (appSettings != null) {
        settings = appSettings;
      } else {
        final list = await db.query('app_settings');
        settings = {
          for (final s in list)
            if (s['key'] != null)
              s['key'].toString(): s['value']?.toString() ?? '',
        };
      }

      final isFemale = CyclePrivacyGuard.isVisible(settings);
      final isCycleEnabled = ModuleGate.instance.isEnabledFrom(
        settings,
        'module_cycle_enabled',
      );
      final consentReminders = settings['cycle_consent_reminders'] == 'true';
      final isPregnant = CycleSettings.isPregnancyMode(settings);

      if (!isFemale || !isCycleEnabled || !consentReminders || isPregnant) {
        await CycleNotificationService.cancelAll();
        return;
      }

      final effectiveNow = now ?? CycleClock.now;
      final engineOutput = await RitmoEngineBus.instance
          .execute<CycleEngineInput, CycleEngineOutput>(
            CycleEngine,
            CycleEngineInput(db: db, appSettings: settings, now: effectiveNow),
          );

      if (engineOutput.hasData && engineOutput.forecast.isNotEmpty) {
        // F-24: Take at most 3 cycles. For cycle #0 (immediate next), always include so new users receive reminders.
        final eligibleCycles = <PredictedCycle>[];
        final candidates = engineOutput.forecast.take(3).toList();
        for (var i = 0; i < candidates.length; i++) {
          final c = candidates[i];
          if (i == 0 || c.confidenceLevel != PredictionConfidenceLevel.low) {
            eligibleCycles.add(c);
          }
        }

        if (eligibleCycles.isNotEmpty) {
          final leadDays = CycleSettings.getReminderLeadDays(settings);
          final reminderHour = CycleSettings.getReminderHour(settings);
          await CycleNotificationService.scheduleForecastReminders(
            forecastCycles: eligibleCycles,
            consentReminders: consentReminders,
            pregnancyMode: isPregnant,
            leadDays: leadDays,
            reminderHour: reminderHour,
            now: effectiveNow,
          );
        } else {
          await CycleNotificationService.cancelAll();
        }
      } else {
        await CycleNotificationService.cancelAll();
      }
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleReminderScheduler] error during rescheduleAll',
        error: e,
        stack: st,
      );
    }
  }
}
