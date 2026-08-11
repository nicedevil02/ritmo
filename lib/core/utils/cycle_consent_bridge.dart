import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/features/cycle/models/cycle_models.dart';

class CycleConsentBridge {
  /// Checks if the user is menstruating on [targetDate] (defaults to today).
  static Future<bool> isUserMenstruating({DateTime? targetDate}) async {
    final db = await DatabaseHelper.instance.database;
    
    // Load app settings
    final settingsList = await db.query('app_settings');
    final settingsMap = {for (final s in settingsList) if (s['key'] != null) s['key'].toString(): s['value']?.toString() ?? ''};

    final pregnancyMode = settingsMap['cycle_pregnancy_mode'] == 'true';
    if (pregnancyMode) {
      return false;
    }

    final target = targetDate ?? DateTime.now();
    final targetStr = target.toIso8601String().substring(0, 10);
    final cleanTarget = DateTime(target.year, target.month, target.day);

    // 1. Check cycle_periods (current ongoing or past period covering targetDate)
    try {
      final periods = await db.query(
        'cycle_periods',
        where: 'startDate <= ?',
        whereArgs: ['${targetStr}T23:59:59'],
        orderBy: 'startDate DESC',
      );

      for (final period in periods) {
        final startStr = period['startDate'] as String?;
        if (startStr == null) continue;
        final start = DateTime.tryParse(startStr);
        if (start == null) continue;
        final cleanStart = DateTime(start.year, start.month, start.day);
        final endStr = period['endDate'] as String?;

        if (endStr != null && endStr.isNotEmpty) {
          final end = DateTime.tryParse(endStr);
          if (end != null) {
            final cleanEnd = DateTime(end.year, end.month, end.day);
            if (!cleanTarget.isBefore(cleanStart) && !cleanTarget.isAfter(cleanEnd)) {
              return true;
            }
          }
        } else {
          // Ongoing active period (no end date recorded yet)
          final daysDiff = cleanTarget.difference(cleanStart).inDays;
          // In Sharia fiqh, period continues until ended or up to 10 days maximum
          if (daysDiff >= 0 && daysDiff <= 10) {
            return true;
          }
        }
      }
    } catch (_) {}

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
    } catch (_) {}

    // 3. Check legacy cycle_logs
    try {
      final oldLogs = await db.query(
        'cycle_logs',
        where: 'cycleStartDate <= ?',
        whereArgs: [targetStr],
        orderBy: 'cycleStartDate DESC',
        limit: 1,
      );
      if (oldLogs.isNotEmpty) {
        final startStr = oldLogs.first['cycleStartDate'] as String?;
        final endStr = oldLogs.first['cycleEndDate'] as String?;
        if (startStr != null) {
          final start = DateTime.tryParse(startStr);
          if (start != null) {
            final cleanStart = DateTime(start.year, start.month, start.day);
            if (endStr != null) {
              final end = DateTime.tryParse(endStr);
              if (end != null) {
                final cleanEnd = DateTime(end.year, end.month, end.day);
                if (!cleanTarget.isBefore(cleanStart) && !cleanTarget.isAfter(cleanEnd)) {
                  return true;
                }
              }
            } else {
              final daysDiff = cleanTarget.difference(cleanStart).inDays;
              if (daysDiff >= 0 && daysDiff <= 10) return true;
            }
          }
        }
      }
    } catch (_) {}

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
    final targetStr = target.toIso8601String().substring(0, 10);
    final cleanTarget = DateTime(target.year, target.month, target.day);

    try {
      final periods = await db.query(
        'cycle_periods',
        where: 'startDate <= ?',
        whereArgs: ['${targetStr}T23:59:59'],
        orderBy: 'startDate DESC',
      );

      for (final period in periods) {
        final startStr = period['startDate'] as String?;
        if (startStr == null) continue;
        final start = DateTime.tryParse(startStr);
        if (start == null) continue;
        final cleanStart = DateTime(start.year, start.month, start.day);
        final endStr = period['endDate'] as String?;

        if (endStr != null && endStr.isNotEmpty) {
          final end = DateTime.tryParse(endStr);
          if (end != null) {
            final cleanEnd = DateTime(end.year, end.month, end.day);
            if (!cleanTarget.isBefore(cleanStart) && !cleanTarget.isAfter(cleanEnd)) {
              return period;
            }
          }
        } else {
          // Ongoing active period (no end date recorded yet)
          final daysDiff = cleanTarget.difference(cleanStart).inDays;
          if (daysDiff >= 0 && daysDiff <= 10) {
            return period;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Checks if worship should be suspended based on consent and active menstruation.
  static Future<bool> isWorshipSuspended({DateTime? targetDate}) async {
    return (await getActivePeriod(targetDate: targetDate)) != null || await isUserMenstruating(targetDate: targetDate);
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
  static Future<void> resolveFastingDebt(String id, bool isResolved) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'fasting_debt',
      {
        'isResolved': isResolved ? 1 : 0,
        'updatedAt': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    // Also update worship_debts for bidirectional sync
    final worshipDebtId = 'debt_cycle_fast_$id';
    final existing = await db.query(
      'worship_debts',
      where: 'id = ?',
      whereArgs: [worshipDebtId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final totalCount = existing.first['totalCount'] as int? ?? 1;
      await db.update(
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
  }
}
