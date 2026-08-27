import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/features/simple_tasks/data/task_preferences.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:sqflite/sqflite.dart';

/// Bridges active daily routines into actionable simple tasks for today.
/// Maximum 5 tasks per day, run at most once per calendar day.
class RoutineTaskBridge {
  static const int maxMaterializedPerDay = 5;

  /// Cleans up orphaned simple tasks belonging to disabled modules or defunct routines.
  static Future<void> cleanOrphanedRoutineTasks(Database db) async {
    try {
      // 1. Clean up any historical orphaned worship debt simple tasks if no active debts exist
      final activeDebts = await db.query(
        'worship_debts',
        where: 'isArchived = 0 AND remainingCount > 0',
        limit: 1,
      );
      if (activeDebts.isEmpty) {
        await db.delete(
          'simple_tasks',
          where: "linkedRoutineId = 'worship_debt_routine' OR title = 'بدهی عبادی'",
        );
      }

      // 2. Clean up simple tasks whose linked routines belong to disabled modules
      final routinesWithCategory = await db.query(
        'routines',
        columns: ['id', 'category'],
        where: 'category IS NOT NULL',
      );
      final disabledRoutineIds = <String>[];
      for (final r in routinesWithCategory) {
        final rId = r['id'] as String?;
        final cat = r['category'] as String? ?? 'personal';
        if (rId != null && !ModuleGate.instance.isCategoryEnabled(cat)) {
          disabledRoutineIds.add(rId);
        }
      }
      if (disabledRoutineIds.isNotEmpty) {
        final placeholders = List.filled(disabledRoutineIds.length, '?').join(',');
        await db.delete(
          'simple_tasks',
          where: 'linkedRoutineId IN ($placeholders)',
          whereArgs: disabledRoutineIds,
        );
      }

      // 3. Clean up unlinked sports tasks if the sports module is disabled
      final sportsEnabled =
          ModuleGate.instance.isEnabled('module_sports_enabled') ||
          ModuleGate.instance.isEnabled('module_supplementary_sports_enabled');
      if (!sportsEnabled) {
        await db.delete(
          'simple_tasks',
          where: "title = 'تمرین قدرتی خانگی' OR title = 'تمرین قدرتی باشگاه'",
        );
      }
    } catch (e, st) {
      RitmoLog.error('RoutineTaskBridge', 'Failed to clean orphaned routine tasks', e, st);
    }
  }

  static Future<int> materializeTodayRoutineTasks({required DateTime now}) async {
    final todayIso = DayKey.from(now).value;

    try {
      final db = await DatabaseHelper.instance.database;

      // Always perform cleanup of orphaned tasks for disabled modules
      await cleanOrphanedRoutineTasks(db);

      // 1. Guard against running more than once per day for creation
      final lastMaterializedDate = await TaskPreferences.getRoutineMaterializedDate();
      if (lastMaterializedDate == todayIso) {
        return 0;
      }

      // 2. Query unarchived active daily routines (excluding 'asNeeded' routines like worship debt / PRN meds)
      final routineRows = await db.query(
        'routines',
        columns: ['id', 'title', 'category'],
        where: "isArchived = 0 AND routineType != 'asNeeded'",
        orderBy: 'displayOrder ASC, createdAt ASC',
        limit: 30,
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
        final routineCategory = r['category'] as String? ?? 'personal';

        // Skip routines belonging to disabled modules
        if (!ModuleGate.instance.isCategoryEnabled(routineCategory)) {
          continue;
        }

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

        await db.insert('simple_tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
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
