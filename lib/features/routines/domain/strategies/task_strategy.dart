import 'package:flutter/material.dart' show BuildContext;
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/routines/domain/strategies/planner_category_strategy.dart';
import 'package:ritmo/features/routines/domain/strategies/planner_save_context.dart';
import 'package:sqflite/sqflite.dart';

/// Strategy that routes one-off tasks created via UniversalPlannerSheet directly to simple_tasks.
class TaskStrategy implements PlannerCategoryStrategy {
  const TaskStrategy();

  @override
  Category get category => Category.work;

  @override
  bool matches(Category category, {String? itemType}) => itemType == 'TASK';

  @override
  bool isModuleEnabled(Object controller) => true;

  @override
  Future<void> save(Object ctx, BuildContext context) async {
    final c = ctx as PlannerSaveContext;
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final taskId = c.routineToEdit?['id']?.toString() ?? 'task_$now';
    final dueDate = c.formatDate(c.selectedDate);
    final dueTime = '${c.selectedTime.hour.toString().padLeft(2, '0')}:${c.selectedTime.minute.toString().padLeft(2, '0')}';
    final isImportant = c.priority > 1.5;

    final existing = await db.query(
      'simple_tasks',
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    final values = {
      'title': c.title,
      'note': c.description.isNotEmpty ? c.description : null,
      'dueDate': dueDate,
      'dueTime': dueTime,
      'isImportant': isImportant ? 1 : 0,
      'updatedAt': now,
    };

    if (existing.isNotEmpty) {
      await db.update('simple_tasks', values, where: 'id = ?', whereArgs: [taskId]);
    } else {
      await db.insert(
        'simple_tasks',
        {
          'id': taskId,
          'isDone': 0,
          'createdAt': now,
          ...values,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }

    RitmoEventBus().fire(RitmoEvent(
      type: 'task_created',
      timestamp: DateTime.now(),
      payload: {'taskId': taskId, 'date': dueDate},
    ));
  }
}
