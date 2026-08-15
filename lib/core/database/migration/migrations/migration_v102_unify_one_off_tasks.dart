import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

/// Migration v102: Unify one-off tasks from routines into simple_tasks (Phase M2-C / P4).
///
/// Rules:
/// 1. Only one-off tasks (single day, no recurrence) are copied to simple_tasks.
/// 2. Tasks with recurring schedules (daysOfWeek or recurrenceRule) stay in routines.
/// 3. Existing simple_tasks schema and indexes are ensured.
class MigrationV102UnifyOneOffTasks extends Migration {
  @override
  int get version => 102;

  @override
  bool get requiresTransaction => true;

  @override
  Future<void> up(DatabaseExecutor db) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    // 1. Ensure simple_tasks table structure
    await db.execute('''
      CREATE TABLE IF NOT EXISTS simple_tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        note TEXT,
        dueDate TEXT,
        dueTime TEXT,
        isDone INTEGER NOT NULL DEFAULT 0,
        doneAt INTEGER,
        isImportant INTEGER NOT NULL DEFAULT 0,
        importantAt INTEGER,
        orderIndex INTEGER NOT NULL DEFAULT 0,
        origin TEXT,
        titleNormalized TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      );
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_simple_tasks_isDone ON simple_tasks(isDone);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_simple_tasks_dueDate ON simple_tasks(dueDate);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_simple_tasks_important ON simple_tasks(isImportant);');

    // 2. Query all active routine rows with itemType = 'TASK'
    final taskRoutines = await db.query(
      'routines',
      where: "itemType = 'TASK' AND isArchived = 0",
    );

    for (final routine in taskRoutines) {
      final routineId = routine['id'] as String?;
      if (routineId == null) continue;

      final schedules = await db.query(
        'routine_schedules',
        where: 'routineId = ?',
        whereArgs: [routineId],
      );

      final schedule = schedules.isNotEmpty ? schedules.first : null;
      final daysOfWeek = schedule?['daysOfWeek'] as String?;
      final recurrenceRule = schedule?['recurrenceRule'] as String?;

      // Check if routine has recurring days or recurring rule
      final isRecurring = _isScheduleRecurring(daysOfWeek, recurrenceRule);
      if (isRecurring) {
        // Keep recurring tasks in routines table
        continue;
      }

      // One-off task: copy to simple_tasks
      final completions = await db.query(
        'routine_completions',
        where: 'routineId = ?',
        whereArgs: [routineId],
      );
      final isDone = completions.any((c) => c['resultType'] == 'FULL');

      final dueDate = schedule?['startDate'] as String? ?? todayStr;
      final dueTime = schedule?['timeOfDay'] as String?;
      final priority = (routine['priority'] as num?)?.toDouble() ?? 1.0;
      final isImportant = priority > 1.5 ? 1 : 0;

      await db.insert(
        'simple_tasks',
        {
          'id': routineId,
          'title': routine['title'] ?? '',
          'note': routine['description'],
          'dueDate': dueDate,
          'dueTime': dueTime,
          'isDone': isDone ? 1 : 0,
          'doneAt': isDone ? nowMs : null,
          'isImportant': isImportant,
          'importantAt': isImportant == 1 ? nowMs : null,
          'origin': 'ROUTINE_TASK_MIGRATED',
          'createdAt': routine['createdAt'] ?? nowMs,
          'updatedAt': routine['updatedAt'] ?? nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  bool _isScheduleRecurring(String? daysOfWeek, String? recurrenceRule) {
    if (daysOfWeek != null && daysOfWeek.trim().isNotEmpty) {
      final days = daysOfWeek.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
      if (days.length > 1) return true;
    }

    if (recurrenceRule != null && recurrenceRule.trim().isNotEmpty) {
      final rule = recurrenceRule.toLowerCase();
      if (rule.contains('daily') || rule.contains('weekly') || rule.contains('interval')) {
        return true;
      }
    }

    return false;
  }

  @override
  Future<void> down(DatabaseExecutor db) async {}
}
