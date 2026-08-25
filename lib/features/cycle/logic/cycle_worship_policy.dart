// C-37: CycleWorshipPolicy
// Single canonical authority for prayer and fasting suspension rulings during menstruation.
// Strictly checks female gender, cycle module enablement, and explicit 'cycle_consent_worship'.
// Uses transactional integrity for fasting debts and enforces the 10-day fiqh ceiling.
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:sqflite/sqflite.dart';

class CycleWorshipPolicy {
  const CycleWorshipPolicy._();

  /// Fiqh maximum duration for menstrual bleeding (10 consecutive days).
  static const int maxFiqhBleedingDays = CycleSettings.maxFiqhBleedingDays;

  /// Helper to calculate if [targetDate] falls within bleeding days of [start] (and [end]),
  /// bounded by [ceilingDays] (10 for fiqh worship suspension, 15 for biology/engine).
  static bool isPeriodDayOnDate({
    required DateTime targetDate,
    required DateTime start,
    DateTime? end,
    int ceilingDays = maxFiqhBleedingDays,
  }) {
    final cleanTarget = CycleDateContract.cleanDate(targetDate);
    final cleanStart = CycleDateContract.cleanDate(start);
    if (end != null) {
      final cleanEnd = CycleDateContract.cleanDate(end);
      if (CycleDateContract.inWindow(cleanTarget, cleanStart, cleanEnd)) {
        final days = CycleDateContract.daysBetween(cleanStart, cleanTarget) + 1;
        return days <= ceilingDays;
      }
      return false;
    } else {
      final daysDiff = CycleDateContract.daysBetween(cleanStart, cleanTarget);
      return daysDiff >= 0 && daysDiff < ceilingDays;
    }
  }

  /// Checks whether Islamic worship (Salah / Fasting) is currently suspended.
  /// Returns `false` if:
  /// - User is not an eligible female
  /// - Cycle module is disabled
  /// - `cycle_consent_worship` is not explicitly 'true'
  /// - Pregnancy mode is active
  /// - No active bleeding within the 10-day fiqh window
  static Future<bool> isWorshipSuspended({
    DatabaseExecutor? dbExecutor,
    Map<String, String>? appSettings,
    DateTime? targetDate,
  }) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;

      Map<String, String> settings = appSettings ?? {};
      if (appSettings == null) {
        final rows = await db.query('app_settings');
        settings = {
          for (final r in rows)
            if (r['key'] != null)
              r['key'].toString(): r['value']?.toString() ?? '',
        };
      }

      // 1. Gender & module gate checks
      final isFemale = CyclePrivacyGuard.isVisible(settings);
      final isCycleEnabled = ModuleGate.instance.isEnabledFrom(
        settings,
        'module_cycle_enabled',
      );
      if (!isFemale || !isCycleEnabled) return false;

      // 2. Explicit worship consent check
      final worshipConsent = settings['cycle_consent_worship'] == 'true';
      if (!worshipConsent) return false;

      // 3. Pregnancy mode check
      final isPregnant = CycleSettings.isPregnancyMode(settings);
      if (isPregnant) return false;

      // 4. Check active bleeding on target date
      final effectiveDate = CycleDateContract.cleanDate(
        targetDate ?? CycleClock.now,
      );
      final periods = await db.query('cycle_periods', orderBy: 'startDate ASC');

      for (final p in periods) {
        final start = CycleDateContract.parseDayKey(p['startDate']?.toString());
        if (start == null) continue;
        final end = CycleDateContract.parseDayKey(p['endDate']?.toString());
        if (isPeriodDayOnDate(
          targetDate: effectiveDate,
          start: start,
          end: end,
          ceilingDays: maxFiqhBleedingDays,
        )) {
          return true;
        }
      }
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleWorshipPolicy] error evaluating worship suspension',
        error: e,
        stack: st,
      );
    }

    return false;
  }

  /// Atomically marks a fasting debt as resolved or unresolved in both
  /// `fasting_debt` and `worship_debts` tables within a single database transaction.
  static Future<void> resolveFastingDebt(
    String id,
    bool isResolved, {
    Database? dbExecutor,
  }) async {
    final db = dbExecutor ?? await DatabaseHelper.instance.database;
    final now = CycleClock.nowMillisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.update(
        'fasting_debt',
        {'isResolved': isResolved ? 1 : 0, 'updatedAt': now},
        where: 'id = ?',
        whereArgs: [id],
      );

      final worshipDebtId = 'debt_cycle_fast_$id';
      final existing = await txn.query(
        'worship_debts',
        where: 'id = ?',
        whereArgs: [worshipDebtId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final totalCount = existing.first['totalCount'] as int? ?? 1;
        await txn.update(
          'worship_debts',
          {
            'remainingCount': isResolved ? 0 : totalCount,
            'isArchived': isResolved ? 1 : 0,
            'updatedAt': now,
          },
          where: 'id = ?',
          whereArgs: [worshipDebtId],
        );
      }
    });
  }
}
