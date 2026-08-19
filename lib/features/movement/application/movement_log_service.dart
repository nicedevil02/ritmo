import 'dart:convert';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_workout_log.dart';
import 'package:sqflite/sqflite.dart';

/// سرویس ثبت وقایع تمرین و فعالیت‌های انجام‌شده (MovementLogService)
class MovementLogService {
  MovementLogService({this.db});
  final Database? db;

  Future<Database> get _database async =>
      db ?? await DatabaseHelper.instance.database;

  /// ثبت گذشته‌نگر تمرین انجام‌شده (RetroLog)
  /// تاریخ آینده ممنوع است. در صورت وجود جلسهٔ برنامه‌ریزی‌شدهٔ مشابه در همان روز،
  /// لاگ به آن متصل شده و وضعیت جلسه به completed تغییر می‌یابد.
  Future<MovementWorkoutLog> logRetroWorkout({
    required String activityKindId,
    required String dateIso,
    String? startTime,
    required int durationSec,
    Map<String, dynamic>? metrics,
    String? feeling,
    String? note,
    String? matchedOccurrenceId,
  }) async {
    final parsedDate = DateTime.tryParse(dateIso);
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    if (parsedDate != null &&
        parsedDate.isAfter(todayMidnight.add(const Duration(days: 1)))) {
      throw ArgumentError('ثبت فعالیت برای تاریخ‌های آینده امکان‌پذیر نیست.');
    }

    final db = await _database;
    final logId = 'log_retro_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toUtc().toIso8601String();
    String? occurrenceId = matchedOccurrenceId;

    await db.transaction((txn) async {
      // اگر جلسهٔ تطبیق‌یافته صراحتاً پاس داده نشده باشد، بررسی جلسات برنامه‌ریزی‌شده در همان روز
      if (occurrenceId == null) {
        final existing = await txn.query(
          MovementTables.tableOccurrences,
          where: 'dateIso = ? AND activityKindId = ? AND status = ?',
          whereArgs: [dateIso, activityKindId, 'planned'],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          occurrenceId = existing.first['id'] as String;
        }
      }

      // اگر جلسه پیدا شد، وضعیت آن را به completed تغییر می‌دهیم
      if (occurrenceId != null) {
        await txn.update(
          MovementTables.tableOccurrences,
          {'status': 'completed', 'updatedAt': now},
          where: 'id = ?',
          whereArgs: [occurrenceId],
        );
      }

      // درج رکورد در جدول لاگ‌ها
      await txn.insert(MovementTables.tableWorkoutLogs, {
        'id': logId,
        'occurrenceId': occurrenceId,
        'activityKindId': activityKindId,
        'dateIso': dateIso,
        'startTime': startTime,
        'durationSec': durationSec,
        'metricJson': metrics != null ? jsonEncode(metrics) : null,
        'feeling': feeling,
        'note': note,
        'source': 'retro',
        'createdAt': now,
        'updatedAt': now,
      });
    });

    return MovementWorkoutLog(
      id: logId,
      occurrenceId: occurrenceId,
      activityKindId: activityKindId,
      dateIso: dateIso,
      startTime: startTime,
      durationSec: durationSec,
      metricJson: metrics != null ? jsonEncode(metrics) : null,
      feeling: feeling,
      note: note,
      source: 'retro',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// تکمیل سریع یک جلسهٔ برنامه‌ریزی‌شده (Quick Complete)
  Future<MovementWorkoutLog> quickCompleteOccurrence({
    required String occurrenceId,
    required String activityKindId,
    required String dateIso,
    String? startTime,
    required int durationSec,
    Map<String, dynamic>? metrics,
    String? feeling,
    String? note,
  }) async {
    final db = await _database;
    final logId = 'log_quick_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      // ۱. به‌روزرسانی وضعیت Occurrence
      await txn.update(
        MovementTables.tableOccurrences,
        {'status': 'completed', 'updatedAt': now},
        where: 'id = ?',
        whereArgs: [occurrenceId],
      );

      // ۲. درج لاگ تمرین
      await txn.insert(MovementTables.tableWorkoutLogs, {
        'id': logId,
        'occurrenceId': occurrenceId,
        'activityKindId': activityKindId,
        'dateIso': dateIso,
        'startTime': startTime,
        'durationSec': durationSec,
        'metricJson': metrics != null ? jsonEncode(metrics) : null,
        'feeling': feeling,
        'note': note,
        'source': 'quick',
        'createdAt': now,
        'updatedAt': now,
      });
    });

    return MovementWorkoutLog(
      id: logId,
      occurrenceId: occurrenceId,
      activityKindId: activityKindId,
      dateIso: dateIso,
      startTime: startTime,
      durationSec: durationSec,
      metricJson: metrics != null ? jsonEncode(metrics) : null,
      feeling: feeling,
      note: note,
      source: 'quick',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// ذخیره یا به‌روزرسانی یکپارچهٔ لاگ تمرین
  Future<void> saveWorkoutLog(MovementWorkoutLog log) async {
    final db = await _database;
    await db.insert(
      MovementTables.tableWorkoutLogs,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// دریافت لاگ‌های یک Occurrence
  Future<List<MovementWorkoutLog>> getLogsForOccurrence(
    String occurrenceId,
  ) async {
    final db = await _database;
    final rows = await db.rawQuery(
      '''
      SELECT l.*, k.nameFa as k_nameFa, k.family as k_family, k.icon as k_icon
      FROM ${MovementTables.tableWorkoutLogs} l
      LEFT JOIN ${MovementTables.tableActivityKinds} k ON l.activityKindId = k.id
      WHERE l.occurrenceId = ?
      ORDER BY l.createdAt DESC
      ''',
      [occurrenceId],
    );

    return rows.map((r) {
      MovementActivityKind? kind;
      if (r['k_nameFa'] != null) {
        kind = MovementActivityKind(
          id: r['activityKindId'] as String,
          nameFa: r['k_nameFa'] as String,
          family: r['k_family'] as String? ?? 'general',
          icon: r['k_icon'] as String? ?? 'directions_run',
          primaryMetric: 'duration',
          createdAt: DateTime.now(),
        );
      }
      return MovementWorkoutLog.fromMap(r, activityKind: kind);
    }).toList();
  }

  /// دریافت لاگ‌های یک روز
  Future<List<MovementWorkoutLog>> getLogsForDate(String dateIso) async {
    final db = await _database;
    final rows = await db.rawQuery(
      '''
      SELECT l.*, k.nameFa as k_nameFa, k.family as k_family, k.icon as k_icon
      FROM ${MovementTables.tableWorkoutLogs} l
      LEFT JOIN ${MovementTables.tableActivityKinds} k ON l.activityKindId = k.id
      WHERE l.dateIso = ?
      ORDER BY l.createdAt DESC
      ''',
      [dateIso],
    );

    return rows.map((r) {
      MovementActivityKind? kind;
      if (r['k_nameFa'] != null) {
        kind = MovementActivityKind(
          id: r['activityKindId'] as String,
          nameFa: r['k_nameFa'] as String,
          family: r['k_family'] as String? ?? 'general',
          icon: r['k_icon'] as String? ?? 'directions_run',
          primaryMetric: 'duration',
          createdAt: DateTime.now(),
        );
      }
      return MovementWorkoutLog.fromMap(r, activityKind: kind);
    }).toList();
  }

  /// دریافت لاگ‌های یک بازهٔ تاریخی
  Future<List<MovementWorkoutLog>> getWorkoutLogsForRange({
    required String startDateIso,
    required String endDateIso,
  }) async {
    final db = await _database;
    final rows = await db.rawQuery(
      '''
      SELECT l.*, k.nameFa as k_nameFa, k.family as k_family, k.icon as k_icon
      FROM ${MovementTables.tableWorkoutLogs} l
      LEFT JOIN ${MovementTables.tableActivityKinds} k ON l.activityKindId = k.id
      WHERE l.dateIso >= ? AND l.dateIso <= ?
      ORDER BY l.dateIso ASC, l.createdAt ASC
      ''',
      [startDateIso, endDateIso],
    );

    return rows.map((r) {
      MovementActivityKind? kind;
      if (r['k_nameFa'] != null) {
        kind = MovementActivityKind(
          id: r['activityKindId'] as String,
          nameFa: r['k_nameFa'] as String,
          family: r['k_family'] as String? ?? 'general',
          icon: r['k_icon'] as String? ?? 'directions_run',
          primaryMetric: 'duration',
          createdAt: DateTime.now(),
        );
      }
      return MovementWorkoutLog.fromMap(r, activityKind: kind);
    }).toList();
  }

  /// دریافت لاگ‌های تمرینی یک گونهٔ فعالیت مشخص
  Future<List<MovementWorkoutLog>> getLogsForActivityKind(
    String activityKindId,
  ) async {
    final db = await _database;
    final rows = await db.query(
      MovementTables.tableWorkoutLogs,
      where: 'activityKindId = ?',
      whereArgs: [activityKindId],
      orderBy: 'createdAt DESC',
    );

    return rows.map((r) => MovementWorkoutLog.fromMap(r)).toList();
  }
}
