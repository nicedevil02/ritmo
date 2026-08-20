import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/features/simple_tasks/data/task_preferences.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:sqflite/sqflite.dart';

class MyDayService {
  MyDayService._();
  static final MyDayService instance = MyDayService._();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<void> addToMyDay(String taskId) async {
    try {
      final db = await _db;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.update(
        'simple_tasks',
        {'addedToMyDayAt': nowMs, 'updatedAt': nowMs},
        where: 'id = ?',
        whereArgs: [taskId],
      );
      RitmoEventBus().fire(RitmoEvent(
        type: 'TaskUpdated',
        timestamp: DateTime.now(),
        payload: {'taskId': taskId},
      ));
    } catch (e, st) {
      RitmoLog.error('MyDayService', 'Failed to add task to My Day: $taskId', e, st);
    }
  }

  Future<void> removeFromMyDay(String taskId) async {
    try {
      final db = await _db;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.update(
        'simple_tasks',
        {'addedToMyDayAt': null, 'updatedAt': nowMs},
        where: 'id = ?',
        whereArgs: [taskId],
      );
      RitmoEventBus().fire(RitmoEvent(
        type: 'TaskUpdated',
        timestamp: DateTime.now(),
        payload: {'taskId': taskId},
      ));
    } catch (e, st) {
      RitmoLog.error('MyDayService', 'Failed to remove task from My Day: $taskId', e, st);
    }
  }

  Future<List<SimpleTask>> myDayTasks() async {
    try {
      final db = await _db;
      final rows = await db.query(
        'simple_tasks',
        where: 'addedToMyDayAt IS NOT NULL',
        orderBy: 'isDone ASC, isImportant DESC, addedToMyDayAt ASC',
      );
      return rows.map((m) => SimpleTask.fromMap(m)).toList();
    } catch (e, st) {
      RitmoLog.error('MyDayService', 'Failed to fetch My Day tasks', e, st);
      return [];
    }
  }

  Future<void> resetIfNewDay() async {
    try {
      final today = DayKey.from(DateTime.now()).value;
      final lastReset = await TaskPreferences.getMyDayLastReset();
      if (lastReset == today) return;

      final db = await _db;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.update(
        'simple_tasks',
        {'addedToMyDayAt': null, 'updatedAt': nowMs},
        where: 'addedToMyDayAt IS NOT NULL',
      );
      await TaskPreferences.setMyDayLastReset(today);
      RitmoLog.info('MyDayService', 'My Day reset performed for $today (previous: $lastReset)');
    } catch (e, st) {
      RitmoLog.error('MyDayService', 'Failed to reset My Day', e, st);
    }
  }
}
