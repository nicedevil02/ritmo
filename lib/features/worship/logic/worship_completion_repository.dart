import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/features/worship/logic/worship_repository.dart';
import 'package:ritmo/features/worship/logic/worship_cache_bus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ritmo/features/worship/domain/prayer_log_quality.dart';

class WorshipDayStatus {
  const WorshipDayStatus({
    required this.recordId,
    required this.resultType,
    required this.countDone,
    this.countTarget,
  });

  final String recordId;
  final String resultType; // DONE | SKIPPED | PARTIAL | QADA_ADDED | MISSED
  final int countDone;
  final int? countTarget;

  bool get isDone => resultType == 'DONE';
  bool get isSkipped => resultType == 'SKIPPED' || resultType == 'QADA_ADDED';
  bool get isQadaAdded => resultType == 'QADA_ADDED';
  bool get isMissed => resultType == 'MISSED';
}

class WorshipCompletionRepository {
  WorshipCompletionRepository._();
  static final instance = WorshipCompletionRepository._();

  /// Gets worship status for a single date for specified practiceIds (or all if omitted).
  Future<Map<String, WorshipDayStatus>> statusForDate(
    String dateStr, {
    List<String>? practiceIds,
    DatabaseExecutor? txn,
  }) async {
    final db = txn ?? await DatabaseHelper.instance.database;

    String whereClause = 'dateStr = ?';
    final List<dynamic> whereArgs = [dateStr];

    if (practiceIds != null && practiceIds.isNotEmpty) {
      whereClause += ' AND practiceId IN (${List.filled(practiceIds.length, '?').join(',')})';
      whereArgs.addAll(practiceIds);
    }

    final rows = await db.query(
      'worship_completions',
      where: whereClause,
      whereArgs: whereArgs,
    );

    final resultMap = <String, WorshipDayStatus>{};
    for (final row in rows) {
      final pid = row['practiceId']! as String;
      resultMap[pid] = WorshipDayStatus(
        recordId: row['id']! as String,
        resultType: row['resultType']! as String,
        countDone: row['countDone'] as int? ?? 1,
        countTarget: row['countTarget'] as int?,
      );
    }

    return resultMap;
  }

  /// Single batch query to load status for a range of dates [fromDateStr, toDateStr].
  /// Returns `Map<dateStr, Map<practiceId, WorshipDayStatus>>`.
  Future<Map<String, Map<String, WorshipDayStatus>>> statusForRange(
    String fromDateStr,
    String toDateStr,
  ) async {
    final db = await DatabaseHelper.instance.database;

    final rows = await db.query(
      'worship_completions',
      where: 'dateStr >= ? AND dateStr <= ?',
      whereArgs: [fromDateStr, toDateStr],
    );

    final rangeMap = <String, Map<String, WorshipDayStatus>>{};
    for (final row in rows) {
      final dateStr = row['dateStr']! as String;
      final pid = row['practiceId']! as String;
      final status = WorshipDayStatus(
        recordId: row['id']! as String,
        resultType: row['resultType']! as String,
        countDone: row['countDone'] as int? ?? 1,
        countTarget: row['countTarget'] as int?,
      );

      rangeMap.putIfAbsent(dateStr, () => <String, WorshipDayStatus>{})[pid] = status;
    }

    return rangeMap;
  }

  /// Log practice completion for date. Idempotent REPLACE.
  Future<String> logDone({
    required String practiceId,
    required String dateStr,
    required String practiceType,
    PrayerLogQuality? quality,
    int countDone = 1,
    int? countTarget,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final recordId = 'wc_${practiceId}_$dateStr';

    final resolvedResultType = quality == PrayerLogQuality.qada ? 'QADA_ADDED' : 'DONE';
    
    await db.transaction((txn) async {
      // Check existing record for idempotency and preserving createdAt (Fixes C2, M12)
      final existingRows = await txn.query(
        'worship_completions',
        where: 'id = ?',
        whereArgs: [recordId],
        limit: 1,
      );

      final wasAlreadyQada = existingRows.isNotEmpty && existingRows.first['resultType'] == 'QADA_ADDED';
      final originalCreatedAt = existingRows.isNotEmpty ? (existingRows.first['createdAt'] as int? ?? nowMs) : nowMs;

      final row = <String, dynamic>{
        'id': recordId,
        'practiceId': practiceId,
        'dateStr': dateStr,
        'practiceType': practiceType,
        'resultType': resolvedResultType,
        'countDone': countDone,
        'countTarget': countTarget,
        'loggedAt': nowMs,
        'createdAt': originalCreatedAt,
      };
      if (quality != null) {
        row['quality'] = quality.code;
      }
      
      await txn.insert(
        'worship_completions',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Only increment debt if this is a NEW Qada record (wasn't already QADA_ADDED - Fixes C2)
      if (quality == PrayerLogQuality.qada && !wasAlreadyQada) {
        final debtType = practiceType == 'FASTING'
            ? 'FASTING'
            : (practiceType == 'MUSTAHAB' ? 'MUSTAHAB' : 'PRAYER');
        final debtId = 'debt_${debtType}_$practiceId';

        final existingDebt = await txn.query('worship_debts', where: 'id = ?', whereArgs: [debtId]);
        if (existingDebt.isNotEmpty) {
          await txn.rawUpdate('''
            UPDATE worship_debts
            SET totalCount = totalCount + 1,
                remainingCount = remainingCount + 1,
                isArchived = 0,
                updatedAt = ?
            WHERE id = ?
          ''', [nowMs, debtId]);
        } else {
          final practiceRows = await txn.query(
            'worship_practices',
            columns: ['title'],
            where: 'id = ?',
            whereArgs: [practiceId],
          );
          final title = practiceRows.isNotEmpty && practiceRows.first['title'] != null
              ? practiceRows.first['title'] as String
              : _defaultPracticeTitle(practiceId);

          await txn.insert('worship_debts', {
            'id': debtId,
            'debtType': debtType,
            'sourcePracticeId': practiceId,
            'title': title,
            'totalCount': 1,
            'remainingCount': 1,
            'dailyTarget': 1,
            'autoCreated': 1,
            'isArchived': 0,
            'createdAt': nowMs,
            'updatedAt': nowMs,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      if (dateStr == todayStr) {
        // Sync derived dailyDone on worship_practices only for today
        await txn.update(
          'worship_practices',
          {
            'dailyDone': quality == PrayerLogQuality.qada ? -1 : countDone,
            'dailyDoneDate': dateStr,
            'updatedAt': nowMs,
          },
          where: 'id = ?',
          whereArgs: [practiceId],
        );
      }
    });

    DayAgendaService.instance.invalidateDate(dateStr);
    WorshipRepository.instance.invalidateCache();
    WorshipCacheBus.invalidateAll(dateStr: dateStr);
    RitmoEventBus().fire(RitmoEvent(
      type: 'WorshipUpdated',
      timestamp: DateTime.now(),
      payload: {'date': dateStr, 'practiceId': practiceId},
    ));

    return recordId;
  }

  /// Log practice skip for date. Idempotent REPLACE.
  Future<String> logSkip({
    required String practiceId,
    required String dateStr,
    required String practiceType,
    String? reason,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final recordId = 'wc_${practiceId}_$dateStr';

    await db.transaction((txn) async {
      await txn.insert(
        'worship_completions',
        {
          'id': recordId,
          'practiceId': practiceId,
          'dateStr': dateStr,
          'practiceType': practiceType,
          'resultType': 'SKIPPED',
          'countDone': 0,
          'reason': reason,
          'loggedAt': nowMs,
          'createdAt': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      if (dateStr == todayStr) {
        // Sync derived dailyDone on worship_practices (-1 for skipped)
        await txn.update(
          'worship_practices',
          {
            'dailyDone': -1,
            'dailyDoneDate': dateStr,
            'updatedAt': nowMs,
          },
          where: 'id = ?',
          whereArgs: [practiceId],
        );
      }
    });

    DayAgendaService.instance.invalidateDate(dateStr);
    WorshipRepository.instance.invalidateCache();
    WorshipCacheBus.invalidateAll(dateStr: dateStr);
    RitmoEventBus().fire(RitmoEvent(
      type: 'WorshipUpdated',
      timestamp: DateTime.now(),
      payload: {'date': dateStr, 'practiceId': practiceId},
    ));

    return recordId;
  }

  /// Undo a completion record and reset dailyDone state, safely rolling back debts (Fixes C3, H11).
  Future<bool> undo(String recordId) async {
    final db = await DatabaseHelper.instance.database;

    final rows = await db.query(
      'worship_completions',
      where: 'id = ?',
      whereArgs: [recordId],
      limit: 1,
    );
    if (rows.isEmpty) return false;

    final row = rows.first;
    final practiceId = row['practiceId']! as String;
    final dateStr = row['dateStr']! as String;
    final practiceType = row['practiceType'] as String? ?? 'PRAYER';
    final wasQada = row['resultType'] == 'QADA_ADDED';
    final isSuspendedFasting = practiceType == 'FASTING' && row['resultType'] == 'SKIPPED';
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.delete(
        'worship_completions',
        where: 'id = ?',
        whereArgs: [recordId],
      );

      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      if (dateStr == todayStr) {
        await txn.update(
          'worship_practices',
          {
            'dailyDone': 0,
            'dailyDoneDate': dateStr,
            'updatedAt': nowMs,
          },
          where: 'id = ?',
          whereArgs: [practiceId],
        );
      }

      if (wasQada || isSuspendedFasting) {
        final debtType = practiceType == 'FASTING' ? 'FASTING' : (practiceType == 'MUSTAHAB' ? 'MUSTAHAB' : 'PRAYER');
        final debtId = 'debt_${debtType}_$practiceId';
        await txn.rawUpdate('''
          UPDATE worship_debts
          SET totalCount = MAX(0, totalCount - 1),
              remainingCount = MAX(0, remainingCount - 1),
              updatedAt = ?
          WHERE id = ?
        ''', [nowMs, debtId]);

        await txn.delete(
          'worship_debts',
          where: 'id = ? AND totalCount <= 0 AND remainingCount <= 0',
          whereArgs: [debtId],
        );

        // Synchronize worship_debt_routine archive state when debts reach 0
        final remainingDebts = await txn.query('worship_debts', where: 'isArchived = 0 AND remainingCount > 0', limit: 1);
        if (remainingDebts.isEmpty) {
          await txn.update('routines', {'isArchived': 1, 'updatedAt': nowMs}, where: "id = 'worship_debt_routine'");
          await txn.delete('simple_tasks', where: "linkedRoutineId = 'worship_debt_routine' OR title = 'بدهی عبادی'");
        }
      }
    });

    DayAgendaService.instance.invalidateDate(dateStr);
    WorshipRepository.instance.invalidateCache();
    WorshipCacheBus.invalidateAll(dateStr: dateStr);
    RitmoEventBus().fire(RitmoEvent(
      type: 'WorshipUpdated',
      timestamp: DateTime.now(),
      payload: {'date': dateStr, 'practiceId': practiceId},
    ));

    return true;
  }

  /// Calculate consecutive streak of DONE days up to [upToDateStr] (Fixes H9).
  Future<int> streakFor(String practiceId, {required String upToDateStr}) async {
    final db = await DatabaseHelper.instance.database;

    final practiceRows = await db.query(
      'worship_practices',
      columns: ['reminderFrequency', 'reminderDaysOfWeek'],
      where: 'id = ?',
      whereArgs: [practiceId],
      limit: 1,
    );
    final freq = practiceRows.isNotEmpty ? (practiceRows.first['reminderFrequency'] as String? ?? 'DAILY') : 'DAILY';

    final rows = await db.query(
      'worship_completions',
      columns: ['dateStr', 'resultType'],
      where: 'practiceId = ? AND dateStr <= ?',
      whereArgs: [practiceId, upToDateStr],
      orderBy: 'dateStr DESC',
    );

    if (rows.isEmpty) return 0;

    int streak = 0;
    DateTime? currentExpected;

    // Check if the most recent completion is timely (today or yesterday for daily)
    final firstRowDate = DateTime.tryParse(rows.first['dateStr'] as String);
    final upToDate = DateTime.tryParse(upToDateStr);
    if (firstRowDate != null && upToDate != null) {
      final daysDiff = upToDate.difference(firstRowDate).inDays;
      if (freq == 'DAILY' && daysDiff > 1) {
        return 0; // Streak is broken if no completion today or yesterday
      }
    }

    for (final row in rows) {
      final dStr = row['dateStr'] as String;
      final date = DateTime.tryParse(dStr);
      if (date == null) break;

      if (currentExpected != null) {
        if (freq == 'DAILY') {
          final expectedPrev = currentExpected.subtract(const Duration(days: 1));
          if (date.year != expectedPrev.year ||
              date.month != expectedPrev.month ||
              date.day != expectedPrev.day) {
            break;
          }
        }
      }

      final resType = row['resultType'] as String;

      // Only DONE counts toward a valid streak (Fixes H9 — QADA_ADDED does NOT maintain streak)
      if (resType == 'DONE') {
        streak++;
        currentExpected = date;
      } else {
        // SKIPPED, MISSED or QADA_ADDED breaks the streak
        break;
      }
    }

    return streak;
  }

  String _defaultPracticeTitle(String id) {
    final lower = id.toLowerCase();
    if (lower.contains('fajr')) return 'نماز صبح';
    if (lower.contains('dhuhr')) return 'نماز ظهر';
    if (lower.contains('asr')) return 'نماز عصر';
    if (lower.contains('maghrib')) return 'نماز مغرب';
    if (lower.contains('isha')) return 'نماز عشا';
    if (lower.contains('fasting')) return 'روزه قضا';
    if (lower.contains('tasbih')) return 'تسبیحات حضرت زهرا (س)';
    if (lower.contains('quran')) return 'قرائت قرآن';
    if (lower.contains('dhikr') || lower.contains('zikr')) return 'ذکر روزانه';
    if (lower.contains('mustahab')) return 'مستحبات';
    return 'عبادت قضاشده';
  }
}
