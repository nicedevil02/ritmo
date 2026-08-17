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
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:sqflite/sqflite.dart';

class CycleReminderScheduler {
  const CycleReminderScheduler._();

  /// Re-evaluates cycle predictions and reschedules notifications across all lookahead cycles.
  static Future<void> rescheduleAll({
    Database? dbExecutor,
    Map<String, String>? appSettings,
    DateTime? now,
  }) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;

      Map<String, String> settings = appSettings ?? {};
      if (appSettings == null) {
        final rows = await db.query('app_settings');
        settings = {
          for (final r in rows)
            if (r['key'] != null) r['key'].toString(): r['value']?.toString() ?? '',
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

      final effectiveNow = now ?? DateTime.now();
      final engineOutput = await RitmoEngineBus.instance
          .execute<CycleEngineInput, CycleEngineOutput>(
            CycleEngine,
            CycleEngineInput(
              db: db,
              appSettings: settings,
              now: effectiveNow,
            ),
          );

      if (engineOutput.hasData && engineOutput.nextPeriodWindowStart != null) {
        final cycleLen = engineOutput.stats.avgCycleLength.round();
        await CycleNotificationService.scheduleReminders(
          nextPeriodWindowStart: engineOutput.nextPeriodWindowStart,
          cycleLength: cycleLen > 0 ? cycleLen : 28,
          consentReminders: consentReminders,
          pregnancyMode: isPregnant,
          now: effectiveNow,
        );
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
