import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن ۱۱۷: مقاوم‌سازی داده‌ای و اسکیمایی ماژول چرخهٔ بدن (Cycle Hardening)
class MigrationV117CycleHardening extends Migration {
  @override
  int get version => 117;

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    // ۱. ایجاد ایندکس‌های cycle_periods
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_cycle_periods_startDate ON cycle_periods(startDate);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_cycle_periods_endDate ON cycle_periods(endDate);',
    );

    // ۲. افزودن ستون autoClosed به cycle_periods
    await safeAddColumn(
      db,
      'cycle_periods',
      'autoClosed',
      'INTEGER NOT NULL DEFAULT 0',
    );

    // ۳. نرمال‌سازی کلیدهای تاریخ بدون صفر پیشوند در cycle_periods, cycle_day_logs, cycle_confirmations
    int normalizedPeriods = 0;
    try {
      final periodRows = await db.query('cycle_periods');
      for (final row in periodRows) {
        final id = row['id']?.toString();
        final startRaw = row['startDate']?.toString();
        final endRaw = row['endDate']?.toString();
        final normStart = CycleDateContract.normalizeDayKey(startRaw);
        final normEnd = CycleDateContract.normalizeDayKey(endRaw);

        final updates = <String, dynamic>{};
        if (normStart != null && normStart != startRaw) {
          updates['startDate'] = normStart;
        }
        if (normEnd != null && normEnd != endRaw) {
          updates['endDate'] = normEnd;
        }
        if (updates.isNotEmpty && id != null) {
          await db.update(
            'cycle_periods',
            updates,
            where: 'id = ?',
            whereArgs: [id],
          );
          normalizedPeriods++;
        }
      }
    } catch (e) {
      debugPrint('[MigrationV117] Error normalizing cycle_periods: $e');
    }

    int normalizedLogs = 0;
    try {
      final logRows = await db.query('cycle_day_logs');
      for (final row in logRows) {
        final id = row['id']?.toString();
        final logDateRaw = row['logDate']?.toString();
        final normLogDate = CycleDateContract.normalizeDayKey(logDateRaw);
        if (normLogDate != null && normLogDate != logDateRaw && id != null) {
          await db.update(
            'cycle_day_logs',
            {'logDate': normLogDate},
            where: 'id = ?',
            whereArgs: [id],
          );
          normalizedLogs++;
        }
      }
    } catch (e) {
      debugPrint('[MigrationV117] Error normalizing cycle_day_logs: $e');
    }

    int normalizedConfirms = 0;
    try {
      final confirmRows = await db.query('cycle_confirmations');
      for (final row in confirmRows) {
        final id = row['id']?.toString();
        final targetRaw = row['targetDate']?.toString();
        final normTarget = CycleDateContract.normalizeDayKey(targetRaw);
        if (normTarget != null && normTarget != targetRaw && id != null) {
          await db.update(
            'cycle_confirmations',
            {'targetDate': normTarget},
            where: 'id = ?',
            whereArgs: [id],
          );
          normalizedConfirms++;
        }
      }
    } catch (e) {
      debugPrint('[MigrationV117] Error normalizing cycle_confirmations: $e');
    }

    // ۴. پاکسازی رکوردهای خراب cycle_confirmations (تأخیرهای با تاریخ آینده یا createdAt خراب)
    int cleanedConfirms = 0;
    try {
      final todayKey = CycleDateContract.toDayKey(DateTime.now());
      cleanedConfirms = await db.delete(
        'cycle_confirmations',
        where: "(kind = 'startOverdue' AND targetDate > ?) OR createdAt <= 0",
        whereArgs: [todayKey],
      );
    } catch (e) {
      debugPrint(
        '[MigrationV117] Error cleaning corrupt cycle_confirmations: $e',
      );
    }

    // ۵. اصلاح چند دورهٔ باز همزمان (بستن دوره‌های قدیمی‌تر با autoClosed = 1)
    int closedOldOpen = 0;
    try {
      // Fetch user's period duration setting if configured (fallback 6 days)
      int userDurationDays = 6;
      try {
        final settingsRows = await db.query(
          'app_settings',
          where:
              "key = 'period_duration_days' OR key = 'user_period_duration_days'",
        );
        for (final s in settingsRows) {
          final val = int.tryParse(s['value']?.toString() ?? '');
          if (val != null && val >= 3 && val <= 10) {
            userDurationDays = val;
            break;
          }
        }
      } catch (_) {}

      final openPeriods = await db.query(
        'cycle_periods',
        where: 'endDate IS NULL',
        orderBy: 'startDate DESC',
      );
      if (openPeriods.length > 1) {
        for (var i = 1; i < openPeriods.length; i++) {
          final oldOpen = openPeriods[i];
          final id = oldOpen['id']?.toString();
          final startRaw = oldOpen['startDate']?.toString();
          final startDt = CycleDateContract.parseDayKey(startRaw);
          if (id != null && startDt != null) {
            final estimatedEnd = startDt.add(
              Duration(days: userDurationDays - 1),
            );
            final endKey = CycleDateContract.toDayKey(estimatedEnd);
            final existingNote = oldOpen['note']?.toString() ?? '';
            final newNote = existingNote.isNotEmpty
                ? '$existingNote [auto-closed]'
                : '[auto-closed]';
            await db.update(
              'cycle_periods',
              {
                'endDate': endKey,
                'autoClosed': 1,
                'note': newNote,
                'updatedAt': DateTime.now().millisecondsSinceEpoch,
              },
              where: 'id = ?',
              whereArgs: [id],
            );
            closedOldOpen++;
          }
        }
      }
    } catch (e) {
      debugPrint('[MigrationV117] Error closing multiple open periods: $e');
    }

    // ۶. ایجاد ایندکس یکتا برای تضمین عدم وجود چند دورهٔ باز همزمان
    try {
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS uq_cycle_periods_single_open ON cycle_periods(autoClosed) WHERE endDate IS NULL;',
      );
    } catch (e) {
      debugPrint('[MigrationV117] Error creating unique open period index: $e');
    }

    debugPrint(
      '[MigrationV117] Cycle hardening completed: normalizedPeriods=$normalizedPeriods, normalizedLogs=$normalizedLogs, normalizedConfirms=$normalizedConfirms, cleanedConfirms=$cleanedConfirms, closedOldOpen=$closedOldOpen',
    );
  }

  @override
  Future<void> down(covariant DatabaseExecutor db) async {
    await db.execute('DROP INDEX IF EXISTS index_cycle_periods_startDate;');
    await db.execute('DROP INDEX IF EXISTS index_cycle_periods_endDate;');
    await db.execute('DROP INDEX IF EXISTS uq_cycle_periods_single_open;');
  }
}
