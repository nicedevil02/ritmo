import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:ritmo/features/cycle/models/cycle_models.dart';

class CycleConsentBridge {
  /// Checks if the user is menstruating on [targetDate] (defaults to today).
  static Future<bool> isUserMenstruating({DateTime? targetDate}) async {
    final db = await DatabaseHelper.instance.database;
    
    // Load app settings
    final settingsList = await db.query('app_settings');
    final settingsMap = {for (final s in settingsList) if (s['key'] != null) s['key'].toString(): s['value']?.toString() ?? ''};

    if (CycleSettings.isPregnancyMode(settingsMap)) {
      return false;
    }

    final isFemale = CyclePrivacyGuard.isVisible(settingsMap);
    final isEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_cycle_enabled');
    if (!isFemale || !isEnabled) {
      return false;
    }

    final target = targetDate ?? DateTime.now();
    final cleanTarget = CycleDateContract.cleanDate(target);
    final targetStr = CycleDateContract.toDayKey(cleanTarget);

    // 1. Check cycle_periods (current ongoing or past period covering targetDate)
    try {
      final periods = await db.query(
        'cycle_periods',
        where: 'startDate <= ?',
        whereArgs: [targetStr],
        orderBy: 'startDate DESC',
      );

      for (final period in periods) {
        final start = CycleDateContract.parseDayKey(period['startDate']?.toString());
        if (start == null) continue;
        final end = CycleDateContract.parseDayKey(period['endDate']?.toString());

        if (end != null) {
          if (CycleDateContract.inWindow(cleanTarget, start, end)) {
            return true;
          }
        } else {
          // Ongoing active period (no end date recorded yet)
          final daysDiff = CycleDateContract.daysBetween(start, cleanTarget);
          if (daysDiff >= 0 && daysDiff <= 10) {
            return true;
          }
        }
      }
    } catch (e, st) {
      RitmoLogger.error('[CycleConsentBridge] error querying cycle_periods', error: e, stack: st);
    }

    // 2. Check cycle_day_logs for targetStr
    try {
      final dayLogs = await db.query(
        'cycle_day_logs',
        where: 'logDate = ?',
        whereArgs: [targetStr],
        limit: 1,
      );
      if (dayLogs.isNotEmpty) {
        final flow = (dayLogs.first['flowLevel'] as String?)?.toUpperCase();
        if (flow != null && flow != 'NONE' && flow != 'NONE_CLEAN' && flow != '') {
          return true;
        }
      }
    } catch (e, st) {
      RitmoLogger.error('[CycleConsentBridge] error querying cycle_day_logs', error: e, stack: st);
    }

    // Note: legacy cycle_logs have been migrated to cycle_periods by migration_v92

    return false;
  }

  /// Checks if energy level tuning is consented by the user.
  static Future<bool> isEnergyTuned() async {
    final db = await DatabaseHelper.instance.database;
    final settingsList = await db.query('app_settings');
    final settingsMap = {for (final s in settingsList) if (s['key'] != null) s['key'].toString(): s['value']?.toString() ?? ''};

    final isFemale = CyclePrivacyGuard.isVisible(settingsMap);
    final energyConsent = settingsMap['cycle_consent_energy'] == 'true';

    return isFemale && energyConsent && (await isUserMenstruating());
  }

  /// Returns the active period for [targetDate] if any.
  static Future<Map<String, dynamic>?> getActivePeriod({DateTime? targetDate}) async {
    final db = await DatabaseHelper.instance.database;
    final target = targetDate ?? DateTime.now();
    final cleanTarget = CycleDateContract.cleanDate(target);
    final targetStr = CycleDateContract.toDayKey(cleanTarget);

    try {
      final periods = await db.query(
        'cycle_periods',
        where: 'startDate <= ?',
        whereArgs: [targetStr],
        orderBy: 'startDate DESC',
      );

      for (final period in periods) {
        final start = CycleDateContract.parseDayKey(period['startDate']?.toString());
        if (start == null) continue;
        final end = CycleDateContract.parseDayKey(period['endDate']?.toString());

        if (end != null) {
          if (CycleDateContract.inWindow(cleanTarget, start, end)) {
            return period;
          }
        } else {
          // Ongoing active period (no end date recorded yet)
          final daysDiff = CycleDateContract.daysBetween(start, cleanTarget);
          if (daysDiff >= 0 && daysDiff <= 10) {
            return period;
          }
        }
      }
    } catch (e, st) {
      RitmoLogger.error('[CycleConsentBridge] error in getActivePeriod', error: e, stack: st);
    }

    return null;
  }

  /// Checks if worship should be suspended based on consent and active menstruation.
  /// Delegates directly to canonical [CycleWorshipPolicy].
  static Future<bool> isWorshipSuspended({DateTime? targetDate}) async {
    return CycleWorshipPolicy.isWorshipSuspended(targetDate: targetDate);
  }

  /// Exposes indirect body rhythm information to outer systems.
  static Future<BodyRhythmInfluence?> bodyRhythmInfluence({required String forSystem}) async {
    final db = await DatabaseHelper.instance.database;
    final settingsList = await db.query('app_settings');
    final settingsMap = {for (final s in settingsList) if (s['key'] != null) s['key'].toString(): s['value']?.toString() ?? ''};

    final isFemale = CyclePrivacyGuard.isVisible(settingsMap);
    final cycleEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_cycle_enabled');
    if (!isFemale || !cycleEnabled) return null;

    final menstruating = await isUserMenstruating();
    if (!menstruating) return null;

    if (forSystem == 'energy') {
      final consent = settingsMap['cycle_consent_energy'] == 'true';
      if (!consent) return null;
      return BodyRhythmInfluence(
        energyDelta: -15,
        indirectMessage: 'بر اساس ریتم طبیعی بدنتان در این روزها، سطح انرژی شما تحت تأثیر نوسانات زیستی قرار دارد و استراحت بیشتری پیشنهاد می‌شود.',
      );
    }

    if (forSystem == 'sleep') {
      final consent = settingsMap['cycle_consent_sleep'] == 'true';
      if (!consent) return null;
      return BodyRhythmInfluence(
        energyDelta: -10,
        indirectMessage: 'بر اساس ریتم طبیعی بدنتان، کیفیت خواب ممکن است با تغییرات زیستی مواجه شود. تلاش کنید خواب منظم‌تری داشته باشید.',
      );
    }

    return null;
  }

  /// Fasting Debt CRUD - Fetch all debts
  static Future<List<FastingDebt>> getFastingDebts() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> rows = await db.query('fasting_debt', orderBy: 'dateIso DESC');
    return rows.map(FastingDebt.fromMap).toList();
  }

  /// Fasting Debt CRUD - Update resolution status
  /// Delegates to canonical [CycleWorshipPolicy.resolveFastingDebt] for transactional integrity.
  static Future<void> resolveFastingDebt(String id, bool isResolved) async {
    await CycleWorshipPolicy.resolveFastingDebt(id, isResolved);
  }
}
