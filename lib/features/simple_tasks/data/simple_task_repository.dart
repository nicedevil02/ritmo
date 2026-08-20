import 'dart:async';
import 'dart:convert';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/utils/persian_text.dart';
import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/features/simple_tasks/data/task_attachment_repository.dart';
import 'package:ritmo/features/simple_tasks/data/task_step_repository.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:ritmo/features/simple_tasks/domain/task_bucket.dart';
import 'package:ritmo/features/simple_tasks/logic/task_bucketing.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ritmo/features/simple_tasks/domain/task_step.dart';
import 'package:ritmo/features/simple_tasks/domain/task_attachment.dart';
import 'package:ritmo/features/simple_tasks/logic/task_tag_parser.dart';

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
  Future<List<SimpleTask>> dueTodayOrOverdue(String todayIso) async {
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
      RitmoLog.error('SimpleTaskRepository', 'Error loading dueTodayOrOverdue tasks', e, st);
      return [];
    }
  }

  /// Backward compatible alias for dueTodayOrOverdue
  Future<List<SimpleTask>> today(String todayIso) => dueTodayOrOverdue(todayIso);

  /// Returns count of active overdue tasks (isDone = 0 AND dueDate < todayIso)
  Future<int> countOverdue(String todayIso) async {
    try {
      final db = await _db;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as total FROM simple_tasks WHERE isDone = 0 AND dueDate IS NOT NULL AND dueDate < ?',
        [todayIso],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e, st) {
      RitmoLog.error('SimpleTaskRepository', 'Error counting overdue tasks', e, st);
      return 0;
    }
  }

  /// Returns count of active tasks due today (isDone = 0 AND dueDate = todayIso)
  Future<int> countDueToday(String todayIso) async {
    try {
      final db = await _db;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as total FROM simple_tasks WHERE isDone = 0 AND dueDate = ?',
        [todayIso],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e, st) {
      RitmoLog.error('SimpleTaskRepository', 'Error counting dueToday tasks', e, st);
      return 0;
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
        where: 'isDone = 1 AND doneAt >= ? AND doneAt < ?',
        whereArgs: [startOfDayMs, endOfDayMs],
        orderBy: 'doneAt DESC, updatedAt DESC',
      );
      return rows.map((m) => SimpleTask.fromMap(m)).toList();
    } catch (e, st) {
      RitmoLog.error('SimpleTaskRepository', 'Error loading doneToday tasks', e, st);
      return [];
    }
  }

  /// Returns all active and done tasks grouped into TaskBucket sections
  Future<Map<TaskBucket, List<SimpleTask>>> buckets(
    String todayIso, {
    TaskSortMode sortMode = TaskSortMode.smart,
    bool hideCompleted = false,
  }) async {
    try {
      final db = await _db;
      final dt = DateTime.tryParse(todayIso) ?? DateTime.now();
      final startOfDayMs = DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch;
      final endOfDayMs = DateTime(dt.year, dt.month, dt.day + 1).millisecondsSinceEpoch;

      final rows = await db.query(
        'simple_tasks',
        where: hideCompleted
            ? 'isDone = 0'
            : 'isDone = 0 OR (isDone = 1 AND doneAt >= ? AND doneAt < ?)',
        whereArgs: hideCompleted ? null : [startOfDayMs, endOfDayMs],
      );

      final tasks = rows.map((m) => SimpleTask.fromMap(m)).toList();
      return groupTasks(
        tasks,
        now: dt,
        sortMode: sortMode,
        hideCompleted: hideCompleted,
      );
    } catch (e, st) {
      RitmoLog.error('SimpleTaskRepository', 'Error loading buckets', e, st);
      return {};
    }
  }

  /// Creates a new SimpleTask within a database transaction
  Future<SimpleTask> create({
    required String title,
    String? dueDate,
    String? dueTime,
    String? note,
    List<String>? tags,
    int? reminderAtMs,
    String? reminderId,
    bool isImportant = false,
  }) async {
    final db = await _db;
    final now = DateTime.now();

    final parsed = parseTags(title);
    final finalTitle = parsed.cleanTitle.isNotEmpty ? parsed.cleanTitle : title.trim();
    final finalTags = (tags != null && tags.isNotEmpty) ? tags : parsed.tags;

    return await db.transaction((txn) async {
      final maxOrderRows = await txn.rawQuery('SELECT MAX(orderIndex) as maxOrder FROM simple_tasks');
      final maxOrder = (maxOrderRows.first['maxOrder'] as int?) ?? 0;

      final task = SimpleTask(
        id: RitmoIdFactory.task(),
        title: finalTitle,
        note: note?.trim(),
        tags: finalTags,
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

      await txn.insert('simple_tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      RitmoEventBus().fire(RitmoEvent(
        type: 'TaskCreated',
        timestamp: DateTime.now(),
        payload: {'date': task.dueDate ?? '', 'taskId': task.id},
      ));

      return task;
    });
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
        await NotificationGateway.cancel(task.reminderId!);
      } catch (e, st) {
        RitmoLog.warning('SimpleTaskRepository', 'Failed to cancel reminder on setDone', e, st);
      }
    } else if (!done && task.reminderId != null && task.reminderAtMs != null) {
      if (task.reminderAtMs! > nowMs) {
        try {
          await NotificationGateway.schedule(
            NotificationRequest(
              id: task.reminderId!,
              channel: NotificationChannelId.planning,
              scheduledAt: DateTime.fromMillisecondsSinceEpoch(task.reminderAtMs!),
              title: task.title,
              sourceSystem: 'tasks',
              entityId: task.id,
            ),
          );
        } catch (e, st) {
          RitmoLog.error('SimpleTaskRepository', 'Failed to reschedule reminder on setDone(false)', e, st);
        }
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
    RitmoEventBus().fire(RitmoEvent(
      type: 'TaskToggled',
      timestamp: DateTime.now(),
      payload: {'date': task.dueDate ?? '', 'taskId': id, 'isDone': done},
    ));
  }

  /// Update full task data
  Future<void> updateTask(SimpleTask task) async {
    final db = await _db;
    final parsed = parseTags(task.title);
    final finalTitle = parsed.cleanTitle.isNotEmpty ? parsed.cleanTitle : task.title.trim();
    final finalTags = task.tags.isNotEmpty ? task.tags : parsed.tags;
    final updated = task.copyWith(
      title: finalTitle,
      tags: finalTags,
      updatedAt: DateTime.now(),
    );
    await db.update(
      'simple_tasks',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
    RitmoEventBus().fire(RitmoEvent(
      type: 'TaskUpdated',
      timestamp: DateTime.now(),
      payload: {'date': task.dueDate ?? '', 'taskId': task.id},
    ));
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

  /// Returns all tasks in the database
  Future<List<SimpleTask>> getAll() async {
    try {
      final db = await _db;
      final rows = await db.query('simple_tasks', orderBy: 'orderIndex ASC, createdAt ASC');
      return rows.map((m) => SimpleTask.fromMap(m)).toList();
    } catch (e, st) {
      RitmoLog.error('SimpleTaskRepository', 'Error loading all tasks', e, st);
      return [];
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
          await NotificationGateway.schedule(
            NotificationRequest(
              id: snapshot.task.reminderId!,
              channel: NotificationChannelId.planning,
              scheduledAt: DateTime.fromMillisecondsSinceEpoch(snapshot.task.reminderAtMs!),
              title: snapshot.task.title,
              sourceSystem: 'tasks',
              entityId: snapshot.task.id,
            ),
          );
        } catch (e, st) {
          RitmoLog.error('SimpleTaskRepository', 'Failed to reschedule reminder in restoreTask', e, st);
        }
      }
    }
    RitmoEventBus().fire(RitmoEvent(
      type: 'TaskUpdated',
      timestamp: DateTime.now(),
      payload: {'date': snapshot.task.dueDate ?? '', 'taskId': snapshot.task.id},
    ));
  }

  /// Delete task + steps + attachments + cancel alarm (alias for deleteTask)
  Future<TaskSnapshot?> delete(String id) => deleteTask(id);

  /// Delete task and related steps + attachments (returns snapshot for undo)
  Future<TaskSnapshot?> deleteTask(String id) async {
    final db = await _db;
    final task = await getById(id);
    if (task == null) return null;

    final steps = await TaskStepRepository.instance.getForTask(id);
    final attachments = await TaskAttachmentRepository.instance.getForTask(id);

    // Cancel alarm if active via unified NotificationGateway
    if (task.reminderId != null && task.reminderId!.isNotEmpty) {
      try {
        await NotificationGateway.cancel(task.reminderId!);
      } catch (e, st) {
        RitmoLog.warning('SimpleTaskRepository', 'Failed to cancel reminder in deleteTask', e, st);
      }
    }

    await TaskStepRepository.instance.deleteForTask(id);
    await TaskAttachmentRepository.instance.deleteForTask(id);
    await db.delete('simple_tasks', where: 'id = ?', whereArgs: [id]);
    
    RitmoEventBus().fire(RitmoEvent(
      type: 'TaskUpdated',
      timestamp: DateTime.now(),
      payload: {'date': task.dueDate ?? '', 'taskId': task.id},
    ));

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

  /// Search tasks by title, note, sub-step title, or tags
  Future<List<SimpleTask>> search(String query) async {
    final normalized = normalizeFa(query);
    if (normalized.isEmpty) return [];
    final db = await _db;
    final q = '%$normalized%';
    final rows = await db.rawQuery('''
      SELECT DISTINCT t.* FROM simple_tasks t
      LEFT JOIN task_steps s ON s.taskId = t.id
      WHERE t.titleNormalized LIKE ? OR t.noteNormalized LIKE ? OR s.titleNormalized LIKE ? OR t.tagsJson LIKE ?
      ORDER BY t.isDone ASC, t.isImportant DESC, t.updatedAt DESC
      LIMIT 20
    ''', [q, q, q, q]);
    return rows.map((m) => SimpleTask.fromMap(m)).toList();
  }

  /// Returns top tags with at least one active (isDone = 0) task, ordered by count DESC (max 8)
  Future<List<String>> getActiveTags({int limit = 8}) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'simple_tasks',
        columns: ['tagsJson'],
        where: "isDone = 0 AND tagsJson IS NOT NULL AND tagsJson != ''",
      );
      final tagCounts = <String, int>{};
      for (final r in rows) {
        final raw = r['tagsJson'] as String?;
        if (raw != null && raw.isNotEmpty) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is List) {
              for (final t in decoded) {
                final tagStr = t.toString();
                if (tagStr.isNotEmpty) {
                  tagCounts[tagStr] = (tagCounts[tagStr] ?? 0) + 1;
                }
              }
            }
          } catch (_) {}
        }
      }
      final sortedTags = tagCounts.keys.toList()
        ..sort((a, b) => tagCounts[b]!.compareTo(tagCounts[a]!));
      return sortedTags.take(limit).toList();
    } catch (e, st) {
      RitmoLog.error('SimpleTaskRepository', 'Error loading active tags', e, st);
      return [];
    }
  }
}
