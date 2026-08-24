import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/features/simple_tasks/data/task_preferences.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:sqflite/sqflite.dart';

/// Bridges active daily routines into actionable simple tasks for today.
/// Maximum 5 tasks per day, run at most once per calendar day.
class RoutineTaskBridge {
  static const int maxMaterializedPerDay = 5;

  static Future<int> materializeTodayRoutineTasks({required DateTime now}) async {
    final todayIso = DayKey.from(now).value;

    // 1. Guard against running more than once per day
    final lastMaterializedDate = await TaskPreferences.getRoutineMaterializedDate();
    if (lastMaterializedDate == todayIso) {
      return 0;
    }

    try {
      final db = await DatabaseHelper.instance.database;

      // Clean up any historical orphaned worship debt simple tasks if no active debts exist
      final activeDebts = await db.query('worship_debts', where: 'isArchived = 0 AND remainingCount > 0', limit: 1);
      if (activeDebts.isEmpty) {
        await db.delete('simple_tasks', where: "linkedRoutineId = 'worship_debt_routine' OR title = 'بدهی عبادی'");
      }

      // 2. Query unarchived active daily routines (excluding 'asNeeded' routines like worship debt / PRN meds)
      final routineRows = await db.query(
        'routines',
        columns: ['id', 'title'],
        where: "isArchived = 0 AND routineType != 'asNeeded'",
        orderBy: 'displayOrder ASC, createdAt ASC',
        limit: 20,
      );

      if (routineRows.isEmpty) {
        await TaskPreferences.setRoutineMaterializedDate(todayIso);
        return 0;
      }

      // 3. Query existing simple tasks for today to avoid duplicate creation
      final existingTaskRows = await db.query(
        'simple_tasks',
        columns: ['linkedRoutineId'],
        where: 'dueDate = ? AND linkedRoutineId IS NOT NULL',
        whereArgs: [todayIso],
      );

      final existingRoutineIds = existingTaskRows
          .map((r) => r['linkedRoutineId'] as String?)
          .whereType<String>()
          .toSet();

      int createdCount = 0;

      for (final r in routineRows) {
        if (createdCount >= maxMaterializedPerDay) break;

        final routineId = r['id'] as String;
        final routineTitle = r['title'] as String;

        if (existingRoutineIds.contains(routineId)) {
          continue;
        }

        final task = SimpleTask(
          id: RitmoIdFactory.task(),
          title: routineTitle,
          dueDate: todayIso,
          origin: 'PROMOTED',
          linkedRoutineId: routineId,
          isDone: false,
          orderIndex: createdCount + 1,
          createdAt: now,
          updatedAt: now,
        );

        await db.insert('simple_tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        existingRoutineIds.add(routineId);
        createdCount++;
      }

      await TaskPreferences.setRoutineMaterializedDate(todayIso);
      return createdCount;
    } catch (e, st) {
      RitmoLog.error('RoutineTaskBridge', 'Failed to materialize today routine tasks', e, st);
      return 0;
    }
  }
}
