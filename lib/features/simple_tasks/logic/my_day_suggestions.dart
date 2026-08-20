import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';

enum MyDaySuggestionReason {
  overdue,
  dueToday,
  dueTomorrow,
  important,
  fromRoutine,
}

class MyDaySuggestion {
  final SimpleTask task;
  final MyDaySuggestionReason reason;

  const MyDaySuggestion({
    required this.task,
    required this.reason,
  });
}

Future<List<MyDaySuggestion>> buildSuggestions({required DateTime now}) async {
  try {
    final db = await DatabaseHelper.instance.database;
    final todayIso = DayKey.from(now).value;
    final tomorrowIso = DayKey.from(now.add(const Duration(days: 1))).value;

    final rows = await db.query(
      'simple_tasks',
      where: 'isDone = 0 AND addedToMyDayAt IS NULL',
      orderBy: 'dueDate ASC, isImportant DESC, orderIndex ASC',
    );

    final tasks = rows.map((m) => SimpleTask.fromMap(m)).toList();
    final suggestions = <MyDaySuggestion>[];
    final addedIds = <String>{};

    // 1. Overdue: dueDate < todayIso
    for (final task in tasks) {
      if (suggestions.length >= 5) break;
      if (task.dueDate != null && task.dueDate!.compareTo(todayIso) < 0) {
        suggestions.add(MyDaySuggestion(task: task, reason: MyDaySuggestionReason.overdue));
        addedIds.add(task.id);
      }
    }

    // 2. Due today: dueDate == todayIso
    for (final task in tasks) {
      if (suggestions.length >= 5) break;
      if (!addedIds.contains(task.id) && task.dueDate == todayIso) {
        suggestions.add(MyDaySuggestion(task: task, reason: MyDaySuggestionReason.dueToday));
        addedIds.add(task.id);
      }
    }

    // 3. Important: isImportant = 1 and dueDate IS NULL
    for (final task in tasks) {
      if (suggestions.length >= 5) break;
      if (!addedIds.contains(task.id) && task.isImportant && task.dueDate == null) {
        suggestions.add(MyDaySuggestion(task: task, reason: MyDaySuggestionReason.important));
        addedIds.add(task.id);
      }
    }

    // 4. Due tomorrow: dueDate == tomorrowIso (only if total suggestions < 3)
    if (suggestions.length < 3) {
      for (final task in tasks) {
        if (suggestions.length >= 5) break;
        if (!addedIds.contains(task.id) && task.dueDate == tomorrowIso) {
          suggestions.add(MyDaySuggestion(task: task, reason: MyDaySuggestionReason.dueTomorrow));
          addedIds.add(task.id);
        }
      }
    }

    return suggestions;
  } catch (e, st) {
    RitmoLog.error('MyDaySuggestions', 'Failed to build My Day suggestions', e, st);
    return [];
  }
}
