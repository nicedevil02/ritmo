import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/utils/persian_text.dart';
import 'package:ritmo/features/simple_tasks/data/task_attachment_repository.dart';
import 'package:ritmo/features/simple_tasks/data/task_step_repository.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:ritmo/features/simple_tasks/domain/task_bucket.dart';
import 'package:ritmo/features/simple_tasks/logic/task_bucketing.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ritmo/features/simple_tasks/domain/task_step.dart';
import 'package:ritmo/features/simple_tasks/domain/task_attachment.dart';

class TaskSnapshot {
  final SimpleTask task;
  final List<TaskStep> steps;
  final List<TaskAttachment> attachments;
  
  TaskSnapshot({
    required this.task,
    required this.steps,
    required this.attachments,
  });
}

class SimpleTaskRepository {
  SimpleTaskRepository._();
  static final SimpleTaskRepository instance = SimpleTaskRepository._();

  Future<Database> get _db async {
    return await DatabaseHelper.instance.database;
  }

  /// Returns active tasks due today OR overdue past tasks (isDone = 0 AND dueDate <= todayIso)
  Future<List<SimpleTask>> today(String todayIso) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'simple_tasks',
        where: 'isDone = 0 AND dueDate IS NOT NULL AND dueDate <= ?',
        whereArgs: [todayIso],
        orderBy: 'orderIndex ASC, createdAt ASC',
      );
      return rows.map((m) => SimpleTask.fromMap(m)).toList();
    } catch (e, st) {
      RitmoLog.error('SimpleTaskRepository', 'Error loading today tasks', e, st);
      return [];
    }
  }

  /// Returns upcoming tasks (isDone = 0 AND dueDate > todayIso)
  Future<List<SimpleTask>> upcoming(String todayIso) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'simple_tasks',
        where: 'isDone = 0 AND dueDate IS NOT NULL AND dueDate > ?',
        whereArgs: [todayIso],
        orderBy: 'dueDate ASC, orderIndex ASC',
      );
      return rows.map((m) => SimpleTask.fromMap(m)).toList();
    } catch (e, st) {
      RitmoLog.error('SimpleTaskRepository', 'Error loading upcoming tasks', e, st);
      return [];
    }
  }

  /// Returns someday tasks with no dueDate (isDone = 0 AND dueDate IS NULL)
  Future<List<SimpleTask>> someday() async {
    try {
      final db = await _db;
      final rows = await db.query(
        'simple_tasks',
        where: 'isDone = 0 AND dueDate IS NULL',
        orderBy: 'orderIndex ASC, createdAt ASC',
      );
      return rows.map((m) => SimpleTask.fromMap(m)).toList();
    } catch (e, st) {
      RitmoLog.error('SimpleTaskRepository', 'Error loading someday tasks', e, st);
      return [];
    }
  }

  /// Returns tasks completed today
  Future<List<SimpleTask>> doneToday(String todayIso) async {
    try {
      final db = await _db;
      final dt = DateTime.tryParse(todayIso) ?? DateTime.now();
      final startOfDayMs = DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch;
      final endOfDayMs = DateTime(dt.year, dt.month, dt.day + 1).millisecondsSinceEpoch;

      final rows = await db.query(
        'simple_tasks',
        where: 'isDone = 1 AND (dueDate = ? OR (doneAt >= ? AND doneAt < ?))',
        whereArgs: [todayIso, startOfDayMs, endOfDayMs],
        orderBy: 'doneAt DESC, updatedAt DESC',
      );
      return rows.map((m) => SimpleTask.fromMap(m)).toList();
    } catch (e, st) {
      RitmoLog.error('SimpleTaskRepository', 'Error loading doneToday tasks', e, st);
      return [];
    }
  }

  /// Returns all active and done tasks grouped into TaskBucket sections
  Future<Map<TaskBucket, List<SimpleTask>>> buckets(String todayIso) async {
    try {
      final db = await _db;
      final dt = DateTime.tryParse(todayIso) ?? DateTime.now();
      final startOfDayMs = DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch;
      final endOfDayMs = DateTime(dt.year, dt.month, dt.day + 1).millisecondsSinceEpoch;

      final rows = await db.query(
        'simple_tasks',
        where: 'isDone = 0 OR (isDone = 1 AND doneAt >= ? AND doneAt < ?)',
        whereArgs: [startOfDayMs, endOfDayMs],
      );

      final tasks = rows.map((m) => SimpleTask.fromMap(m)).toList();
      return groupTasks(tasks, now: dt);
    } catch (e, st) {
      RitmoLog.error('SimpleTaskRepository', 'Error loading buckets', e, st);
      return {};
    }
  }

  /// Creates a new SimpleTask
  Future<SimpleTask> create({
    required String title,
    String? dueDate,
    String? dueTime,
    String? note,
    int? reminderAtMs,
    String? reminderId,
    bool isImportant = false,
  }) async {
    final db = await _db;
    final now = DateTime.now();

    final maxOrderRows = await db.rawQuery('SELECT MAX(orderIndex) as maxOrder FROM simple_tasks');
    final maxOrder = (maxOrderRows.first['maxOrder'] as int?) ?? 0;

    final task = SimpleTask(
      id: SimpleTask.generateId(),
      title: title.trim(),
      note: note?.trim(),
      isDone: false,
      dueDate: dueDate,
      dueTime: dueTime,
      reminderAtMs: reminderAtMs,
      reminderId: reminderId,
      orderIndex: maxOrder + 1,
      origin: 'SIMPLE',
      isImportant: isImportant,
      importantAt: isImportant ? now : null,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('simple_tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return task;
  }

  /// Toggle task importance star
  Future<void> setImportant(String id, {required bool important}) async {
    final db = await _db;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'simple_tasks',
      {
        'isImportant': important ? 1 : 0,
        'importantAt': important ? nowMs : null,
        'updatedAt': nowMs,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Toggle task completion status + cancel alarm if completed
  Future<void> setDone(String id, {required bool done}) async {
    final db = await _db;
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    final rows = await db.query('simple_tasks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;

    final task = SimpleTask.fromMap(rows.first);

    if (done && task.reminderId != null && task.reminderId!.isNotEmpty) {
      try {
        await sl<AlarmPlatform>().cancelAlarm(task.reminderId!);
      } catch (_) {}
    } else if (!done && task.reminderId != null && task.reminderAtMs != null) {
      if (task.reminderAtMs! > nowMs) {
        try {
          await sl<AlarmPlatform>().scheduleExactAlarm(
            id: task.reminderId!,
            timeMsUTC: task.reminderAtMs!,
            title: task.title,
            isEssential: false,
          );
        } catch (_) {}
      }
    }

    await db.update(
      'simple_tasks',
      {
        'isDone': done ? 1 : 0,
        'doneAt': done ? nowMs : null,
        'updatedAt': nowMs,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update full task data
  Future<void> updateTask(SimpleTask task) async {
    final db = await _db;
    final updated = task.copyWith(updatedAt: DateTime.now());
    await db.update(
      'simple_tasks',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  /// Returns a single task by ID, or null if not found.
  Future<SimpleTask?> getById(String id) async {
    try {
      final db = await _db;
      final rows = await db.query('simple_tasks', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return null;
      return SimpleTask.fromMap(rows.first);
    } catch (e, st) {
      RitmoLog.error('SimpleTaskRepository', 'Error getting task by id: $id', e, st);
      return null;
    }
  }

  /// Save a pending reminder for a task
  Future<void> addPendingReminder({
    required String reminderId,
    required String title,
    required String body,
    required int scheduledTimeMs,
    required String taskId,
  }) async {
    final db = await _db;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'pending_reminders',
      {
        'id': reminderId,
        'title': title,
        'body': body,
        'scheduledTime': scheduledTimeMs,
        'payloadJson': '{"taskId":"$taskId"}',
        'createdAt': nowMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Restore a deleted task (for undo)
  Future<void> restoreTask(TaskSnapshot snapshot) async {
    final db = await _db;
    await db.insert('simple_tasks', snapshot.task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    
    // Restore steps
    for (final step in snapshot.steps) {
      await db.insert('task_steps', step.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    
    // Restore attachments
    for (final att in snapshot.attachments) {
      await db.insert('task_attachments', att.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    
    // Reschedule alarm if needed
    if (!snapshot.task.isDone && snapshot.task.reminderId != null && snapshot.task.reminderAtMs != null) {
      if (snapshot.task.reminderAtMs! > DateTime.now().millisecondsSinceEpoch) {
        try {
          await sl<AlarmPlatform>().scheduleExactAlarm(
            id: snapshot.task.reminderId!,
            timeMsUTC: snapshot.task.reminderAtMs!,
            title: snapshot.task.title,
            isEssential: false,
          );
        } catch (_) {}
      }
    }
  }

  /// Delete task + steps + attachments + cancel alarm
  Future<TaskSnapshot?> delete(String id) async {
    final db = await _db;
    final rows = await db.query('simple_tasks', where: 'id = ?', whereArgs: [id], limit: 1);
    SimpleTask? task;
    
    if (rows.isNotEmpty) {
      task = SimpleTask.fromMap(rows.first);
      if (task.reminderId != null && task.reminderId!.isNotEmpty) {
        try {
          await sl<AlarmPlatform>().cancelAlarm(task.reminderId!);
        } catch (_) {}
      }
    }

    if (task == null) return null;

    final steps = await TaskStepRepository.instance.getForTask(id);
    final attachments = await TaskAttachmentRepository.instance.getForTask(id);

    await TaskStepRepository.instance.deleteForTask(id);
    await TaskAttachmentRepository.instance.deleteForTask(id);
    await db.delete('simple_tasks', where: 'id = ?', whereArgs: [id]);
    
    return TaskSnapshot(
      task: task,
      steps: steps,
      attachments: attachments,
    );
  }

  /// Reorder tasks by ordered list of IDs
  Future<void> reorder(List<String> orderedIds) async {
    final db = await _db;
    final batch = db.batch();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(
        'simple_tasks',
        {'orderIndex': i, 'updatedAt': nowMs},
        where: 'id = ?',
        whereArgs: [orderedIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Mark task as promoted to routine
  Future<void> promoteToRoutine(String id, String routineId) async {
    final db = await _db;
    await db.update(
      'simple_tasks',
      {
        'linkedRoutineId': routineId,
        'origin': 'PROMOTED',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Search tasks by title, note, or sub-step title
  Future<List<SimpleTask>> search(String query) async {
    final normalized = normalizeFa(query);
    if (normalized.isEmpty) return [];
    final db = await _db;
    final q = '%$normalized%';
    final rows = await db.rawQuery('''
      SELECT DISTINCT t.* FROM simple_tasks t
      LEFT JOIN task_steps s ON s.taskId = t.id
      WHERE t.titleNormalized LIKE ? OR t.note LIKE ? OR s.title LIKE ?
      ORDER BY t.isDone ASC, t.isImportant DESC, t.updatedAt DESC
      LIMIT 20
    ''', [q, q, q]);
    return rows.map((m) => SimpleTask.fromMap(m)).toList();
  }
}
