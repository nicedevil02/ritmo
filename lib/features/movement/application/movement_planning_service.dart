import 'dart:convert';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_change_scope.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_plan_schedule.dart';
import 'package:ritmo/features/movement/domain/models/movement_plan_template.dart';
import 'package:sqflite/sqflite.dart';

/// سرویس جامع برنامه‌ریزی و زمان‌بندی جلسات حرکت (MovementPlanningService)
class MovementPlanningService {
  MovementPlanningService({this.db});
  final Database? db;

  Future<Database> get _database async =>
      db ?? await DatabaseHelper.instance.database;

  /// تبدیل تاریخ میلادی به روز هفتهٔ ریتمو (۰=شنبه، ۱=یکشنبه، ...، ۶=جمعه)
  static int getRitmoWeekday(DateTime date) {
    return (date.weekday + 1) % 7;
  }

  /// قالب‌بندی تاریخ به ISO yyyy-MM-dd
  static String formatIso(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// ایجاد یک برنامهٔ جدید شامل قالب + زمان‌بندی‌ها + افق رویدادها در **یک تراکنش اتمیک**
  Future<String> createPlan({
    required String activityKindId,
    String sessionType = 'repeating',
    Map<String, dynamic>? goal,
    String reminderType = 'none',
    int? reminderOffsetMin,
    required List<MovementPlanSchedule> schedules,
    int horizonWeeks = 4,
  }) async {
    final db = await _database;
    final templateId = 'tpl_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      // ۱. ثبت قالب برنامه
      await txn.insert(MovementTables.tablePlanTemplates, {
        'id': templateId,
        'activityKindId': activityKindId,
        'sessionType': sessionType,
        'goalJson': goal != null ? jsonEncode(goal) : null,
        'reminderType': reminderType,
        'reminderOffsetMin': reminderOffsetMin,
        'createdAt': now,
        'updatedAt': now,
        'archivedAt': null,
      });

      // ۲. ثبت زمان‌بندی‌ها و تولید رویدادهای افق ۴ هفته
      for (final schedule in schedules) {
        final scheduleId = schedule.id.isNotEmpty
            ? schedule.id
            : 'sch_${DateTime.now().microsecondsSinceEpoch}_${schedule.weekday}';

        await txn.insert(MovementTables.tablePlanSchedules, {
          'id': scheduleId,
          'templateId': templateId,
          'weekday': schedule.weekday,
          'timeOfDay': schedule.timeOfDay,
          'recurrence': schedule.recurrence,
          'startDateIso': schedule.startDateIso,
          'weeksCount': schedule.weeksCount,
          'createdAt': now,
        });

        // ۳. تولید رخدادها بر اساس نوع تکرار
        final startDate =
            DateTime.tryParse(schedule.startDateIso) ?? DateTime.now();
        final maxWeeks = schedule.recurrence == 'once'
            ? 1
            : (schedule.weeksCount != null && schedule.weeksCount! > 0
                  ? schedule.weeksCount!
                  : horizonWeeks);

        final totalDays = maxWeeks * 7;
        for (int i = 0; i < totalDays; i++) {
          final targetDate = startDate.add(Duration(days: i));
          if (getRitmoWeekday(targetDate) == schedule.weekday) {
            final occId =
                'occ_${DateTime.now().microsecondsSinceEpoch}_${formatIso(targetDate)}';
            await txn.insert(MovementTables.tableOccurrences, {
              'id': occId,
              'activityKindId': activityKindId,
              'templateId': templateId,
              'scheduleId': scheduleId,
              'dateIso': formatIso(targetDate),
              'startTime': schedule.timeOfDay,
              'status': 'planned',
              'goalType': goal?['type'] as String?,
              'goalValue': (goal?['value'] as num?)?.toDouble(),
              'goalUnit': goal?['unit'] as String?,
              'movedToDateIso': null,
              'origin': 'template',
              'createdAt': now,
              'updatedAt': now,
            });

            if (schedule.recurrence == 'once') {
              break;
            }
          }
        }
      }
    });

    return templateId;
  }

  /// دریافت یک قالب برنامه با شناسه‌اش
  Future<MovementPlanTemplate?> getTemplate(String templateId) async {
    final db = await _database;
    final results = await db.rawQuery(
      '''
      SELECT t.*, k.nameFa as k_nameFa, k.nameEn as k_nameEn, k.family as k_family,
             k.icon as k_icon, k.primaryMetric as k_primaryMetric
      FROM ${MovementTables.tablePlanTemplates} t
      LEFT JOIN ${MovementTables.tableActivityKinds} k ON t.activityKindId = k.id
      WHERE t.id = ?
      ''',
      [templateId],
    );

    if (results.isEmpty) return null;
    final row = results.first;
    MovementActivityKind? kind;
    if (row['k_nameFa'] != null) {
      kind = MovementActivityKind(
        id: row['activityKindId'] as String,
        nameFa: row['k_nameFa'] as String,
        nameEn: row['k_nameEn'] as String?,
        family: row['k_family'] as String? ?? 'general',
        icon: row['k_icon'] as String? ?? 'directions_run',
        primaryMetric: row['k_primaryMetric'] as String? ?? 'duration',
        createdAt: DateTime.now(),
      );
    }
    return MovementPlanTemplate.fromMap(row, activityKind: kind);
  }

  /// دریافت زمان‌بندی‌های یک قالب
  Future<List<MovementPlanSchedule>> getSchedules(String templateId) async {
    final db = await _database;
    final rows = await db.query(
      MovementTables.tablePlanSchedules,
      where: 'templateId = ?',
      whereArgs: [templateId],
      orderBy: 'weekday ASC',
    );
    return rows.map((r) => MovementPlanSchedule.fromMap(r)).toList();
  }

  /// ویرایش برنامه با دامنه‌های سه‌گانه
  Future<void> updatePlanWithScope({
    required String templateId,
    required String occurrenceId,
    required String focalDateIso,
    required MovementChangeScope scope,
    Map<String, dynamic>? newGoal,
    String? newStartTime,
    String? newReminderType,
    int? newReminderOffsetMin,
  }) async {
    final db = await _database;
    final now = DateTime.now().toUtc().toIso8601String();

    switch (scope) {
      case MovementChangeScope.onlyThis:
        // فقط همین Occurrence تغییر می‌کند
        final updates = <String, dynamic>{'updatedAt': now};
        if (newStartTime != null) updates['startTime'] = newStartTime;
        if (newGoal != null) {
          updates['goalType'] = newGoal['type'];
          updates['goalValue'] = (newGoal['value'] as num?)?.toDouble();
          updates['goalUnit'] = newGoal['unit'];
        }
        await db.update(
          MovementTables.tableOccurrences,
          updates,
          where: 'id = ?',
          whereArgs: [occurrenceId],
        );
        break;

      case MovementChangeScope.thisAndFuture:
        // جلسات از focalDateIso به بعد تغییر می‌کنند
        final occUpdates = <String, dynamic>{'updatedAt': now};
        if (newStartTime != null) occUpdates['startTime'] = newStartTime;
        if (newGoal != null) {
          occUpdates['goalType'] = newGoal['type'];
          occUpdates['goalValue'] = (newGoal['value'] as num?)?.toDouble();
          occUpdates['goalUnit'] = newGoal['unit'];
        }
        await db.update(
          MovementTables.tableOccurrences,
          occUpdates,
          where: 'templateId = ? AND dateIso >= ? AND status != ?',
          whereArgs: [templateId, focalDateIso, 'completed'],
        );
        break;

      case MovementChangeScope.wholePlan:
        await db.transaction((txn) async {
          // ۱. به‌روزرسانی قالب
          final tplUpdates = <String, dynamic>{'updatedAt': now};
          if (newGoal != null) tplUpdates['goalJson'] = jsonEncode(newGoal);
          if (newReminderType != null)
            tplUpdates['reminderType'] = newReminderType;
          if (newReminderOffsetMin != null)
            tplUpdates['reminderOffsetMin'] = newReminderOffsetMin;

          await txn.update(
            MovementTables.tablePlanTemplates,
            tplUpdates,
            where: 'id = ?',
            whereArgs: [templateId],
          );

          // ۲. به‌روزرسانی تمام جلسات آینده (که هنوز انجام نشده‌اند)
          final occUpdates = <String, dynamic>{'updatedAt': now};
          if (newStartTime != null) occUpdates['startTime'] = newStartTime;
          if (newGoal != null) {
            occUpdates['goalType'] = newGoal['type'];
            occUpdates['goalValue'] = (newGoal['value'] as num?)?.toDouble();
            occUpdates['goalUnit'] = newGoal['unit'];
          }
          await txn.update(
            MovementTables.tableOccurrences,
            occUpdates,
            where: 'templateId = ? AND dateIso >= ? AND status != ?',
            whereArgs: [templateId, focalDateIso, 'completed'],
          );
        });
        break;
    }
  }

  /// جابه‌جایی یک جلسه به روز یا ساعت دیگر
  Future<void> moveOccurrence({
    required String occurrenceId,
    required String newDateIso,
    String? newStartTime,
    MovementChangeScope scope = MovementChangeScope.onlyThis,
  }) async {
    final db = await _database;
    final now = DateTime.now().toUtc().toIso8601String();

    final updateData = <String, Object?>{
      'dateIso': newDateIso,
      'movedToDateIso': newDateIso,
      'status': 'planned',
      'updatedAt': now,
    };
    if (newStartTime != null) {
      updateData['startTime'] = newStartTime;
    }

    await db.update(
      MovementTables.tableOccurrences,
      updateData,
      where: 'id = ?',
      whereArgs: [occurrenceId],
    );
  }

  /// رد کردن (Skip) یک جلسه
  Future<void> skipOccurrence({required String occurrenceId}) async {
    final db = await _database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.update(
      MovementTables.tableOccurrences,
      {'status': 'skipped', 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [occurrenceId],
    );
  }

  /// کوتاه کردن جلسه (Plan B)
  Future<void> shortenOccurrence({
    required String occurrenceId,
    required double newGoalValue,
    String? newGoalUnit,
  }) async {
    final db = await _database;
    final now = DateTime.now().toUtc().toIso8601String();

    final updateData = <String, Object?>{
      'goalValue': newGoalValue,
      'updatedAt': now,
    };
    if (newGoalUnit != null) {
      updateData['goalUnit'] = newGoalUnit;
    }

    await db.update(
      MovementTables.tableOccurrences,
      updateData,
      where: 'id = ?',
      whereArgs: [occurrenceId],
    );
  }

  /// حذف برنامه یا رویداد با حفظ کامل Log تاریخی
  Future<void> deleteWithScope({
    required String occurrenceId,
    required String focalDateIso,
    String? templateId,
    MovementChangeScope scope = MovementChangeScope.onlyThis,
  }) async {
    final db = await _database;

    switch (scope) {
      case MovementChangeScope.onlyThis:
        await db.delete(
          MovementTables.tableOccurrences,
          where: 'id = ? AND status != ?',
          whereArgs: [occurrenceId, 'completed'],
        );
        break;

      case MovementChangeScope.thisAndFuture:
        if (templateId != null) {
          await db.delete(
            MovementTables.tableOccurrences,
            where: 'templateId = ? AND dateIso >= ? AND status != ?',
            whereArgs: [templateId, focalDateIso, 'completed'],
          );
        } else {
          await db.delete(
            MovementTables.tableOccurrences,
            where: 'id = ? AND status != ?',
            whereArgs: [occurrenceId, 'completed'],
          );
        }
        break;

      case MovementChangeScope.wholePlan:
        if (templateId != null) {
          await db.transaction((txn) async {
            // ۱. آرشیو کردن قالب به جای حذف کامل
            await txn.update(
              MovementTables.tablePlanTemplates,
              {
                'archivedAt': DateTime.now().toUtc().toIso8601String(),
                'updatedAt': DateTime.now().toUtc().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [templateId],
            );

            // ۲. حذف تمام جلسات آینده که هنوز انجام نشده‌اند
            await txn.delete(
              MovementTables.tableOccurrences,
              where: 'templateId = ? AND dateIso >= ? AND status != ?',
              whereArgs: [templateId, focalDateIso, 'completed'],
            );
          });
        } else {
          await db.delete(
            MovementTables.tableOccurrences,
            where: 'id = ? AND status != ?',
            whereArgs: [occurrenceId, 'completed'],
          );
        }
        break;
    }
  }

  /// بررسی تداخل‌های زمانی در یک روز خاص
  Future<List<MovementOccurrence>> checkConflicts({
    required String dateIso,
    required String timeOfDay,
    String? excludeOccurrenceId,
  }) async {
    final db = await _database;
    final whereArgs = <dynamic>[dateIso, 'planned'];
    var query =
        '''
      SELECT o.*, k.nameFa as k_nameFa, k.family as k_family, k.icon as k_icon
      FROM ${MovementTables.tableOccurrences} o
      LEFT JOIN ${MovementTables.tableActivityKinds} k ON o.activityKindId = k.id
      WHERE o.dateIso = ? AND o.status = ?
    ''';

    if (excludeOccurrenceId != null) {
      query += ' AND o.id != ?';
      whereArgs.add(excludeOccurrenceId);
    }

    final rows = await db.rawQuery(query, whereArgs);
    final results = <MovementOccurrence>[];
    for (final row in rows) {
      final occTime = row['startTime'] as String?;
      if (occTime != null && occTime.isNotEmpty) {
        final occParts = occTime.split(':');
        final targetParts = timeOfDay.split(':');
        if (occParts.length >= 2 && targetParts.length >= 2) {
          final occMins = (int.tryParse(occParts[0]) ?? 0) * 60 + (int.tryParse(occParts[1]) ?? 0);
          final targetMins = (int.tryParse(targetParts[0]) ?? 0) * 60 + (int.tryParse(targetParts[1]) ?? 0);
          if ((occMins - targetMins).abs() <= 30) {
            MovementActivityKind? kind;
            if (row['k_nameFa'] != null) {
              kind = MovementActivityKind(
                id: row['activityKindId'] as String,
                nameFa: row['k_nameFa'] as String,
                family: row['k_family'] as String? ?? 'general',
                icon: row['k_icon'] as String? ?? 'directions_run',
                primaryMetric: 'duration',
                createdAt: DateTime.now(),
              );
            }
            results.add(MovementOccurrence.fromMap(row, activityKind: kind));
          }
        }
      }
    }
    return results;
  }

  /// تنظیم برنامهٔ سادهٔ هفتگی ۳ سؤالی (P-16 / P-17)
  Future<void> createWeeklySimplePlan({
    required int weeklyGoalSessions,
    required List<int> preferredWeekdays, // 0=شنبه تا 6=جمعه
    required String reminderTime, // e.g. "08:00"
    String activityKindId = 'kind_walking',
    DateTime? fromDate,
  }) async {
    final db = await _database;
    final now = fromDate ?? DateTime.now();
    final todayIso = formatIso(now);

    await db.transaction((txn) async {
      // ۱. ذخیره در جدول Preferences
      await txn.insert(
        MovementTables.tablePreferences,
        {'key': 'weekly_goal_sessions', 'value': weeklyGoalSessions.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        MovementTables.tablePreferences,
        {
          'key': 'preferred_days',
          'value': jsonEncode(preferredWeekdays),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        MovementTables.tablePreferences,
        {'key': 'reminder_hour', 'value': reminderTime},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // ۲. حذف رخدادهای آیندهٔ قبلی با وضعیت planned (گذشته دست‌نخورده می‌ماند)
      await txn.delete(
        MovementTables.tableOccurrences,
        where: 'dateIso >= ? AND status = ?',
        whereArgs: [todayIso, 'planned'],
      );

      // ۳. ایجاد رخدادهای ۴ هفتهٔ آینده
      final sat = DateTime(now.year, now.month, now.day).subtract(
        Duration(days: (now.weekday % 7 + 1) % 7),
      );

      int occCounter = 0;
      for (int week = 0; week < 4; week++) {
        for (final dayIdx in preferredWeekdays) {
          final targetDate = sat.add(Duration(days: (week * 7) + dayIdx));
          final targetIso = formatIso(targetDate);

          // اگر تاریخ در گذشته نباشد، رخداد اضافه شود
          if (!targetDate.isBefore(DateTime(now.year, now.month, now.day))) {
            final occId = 'occ_plan_${targetIso}_${occCounter++}';
            await txn.insert(
              MovementTables.tableOccurrences,
              {
                'id': occId,
                'activityKindId': activityKindId,
                'templateId': null,
                'scheduleId': null,
                'dateIso': targetIso,
                'startTime': reminderTime,
                'status': 'planned',
                'goalType': 'duration',
                'goalValue': 30.0,
                'goalUnit': 'minutes',
                'movedToDateIso': null,
                'origin': 'template',
                'createdAt': DateTime.now().toUtc().toIso8601String(),
                'updatedAt': DateTime.now().toUtc().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }
    });
  }
}
