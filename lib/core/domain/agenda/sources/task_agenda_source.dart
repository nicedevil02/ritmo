import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqflite/sqflite.dart';

class TaskAgendaSource implements AgendaSource {
  TaskAgendaSource({
    required this.tasksByDate,
    required this.overdueTasks,
    required this.datelessTasks,
    required this.totalOverdueCount,
    required this.stepCounts,
  });

  /// dateStr -> rows of simple_tasks
  final Map<String, List<Map<String, dynamic>>> tasksByDate;

  /// کارهای انجام‌نشده با dueDate قبل از امروز (حداکثر ۲۰ مورد)
  final List<Map<String, dynamic>> overdueTasks;

  /// کارهای بدون تاریخ (فقط برای نمایش در روز جاری)
  final List<Map<String, dynamic>> datelessTasks;

  /// کل تعداد کارهای معوقه در بازهٔ بازگشت
  final int totalOverdueCount;

  /// taskId -> (done, total)
  final Map<String, ({int done, int total})> stepCounts;

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.task};

  @override
  bool get isEnabled => true;

  static Future<TaskAgendaSource> load(
    Database db,
    DateTime start,
    DateTime end,
    String todayStr, [
    String? appStartDateStr,
    int lookbackDays = 14,
  ]) async {
    try {
      final startStr = DateKey.of(start);
      final endStr = DateKey.of(end);

      // 1) All tasks scheduled within range (dueDate >= startStr AND dueDate <= endStr)
      final rangeRows = await db.query(
        'simple_tasks',
        where: 'dueDate >= ? AND dueDate <= ?',
        whereArgs: [startStr, endStr],
        orderBy: 'dueTime ASC, isImportant DESC, updatedAt DESC',
      );

      final tasksByDate = <String, List<Map<String, dynamic>>>{};
      final taskIds = <String>{};
      for (final r in rangeRows) {
        final dStr = r['dueDate'] as String?;
        if (dStr != null) {
          tasksByDate.putIfAbsent(dStr, () => []).add(r);
          taskIds.add(r['id'].toString());
        }
      }

      // 2) Dateless pending tasks (M2-7)
      final datelessRows = await db.query(
        'simple_tasks',
        where: "isDone = 0 AND (dueDate IS NULL OR dueDate = '')",
        orderBy: 'isImportant DESC, updatedAt DESC',
      );
      for (final r in datelessRows) {
        taskIds.add(r['id'].toString());
      }

      // 3) Overdue tasks with configurable lookback window (M2-7)
      final parsedToday = DateKey.parse(todayStr) ?? DateTime.tryParse(todayStr) ?? DateTime.now();
      final lookbackDate = DateKey.addDays(
        parsedToday,
        -(lookbackDays > 0 ? lookbackDays : 14),
      );
      final lookbackStartStr = DateKey.of(lookbackDate);

      String effectiveStartDate = lookbackStartStr;
      if (appStartDateStr != null &&
          appStartDateStr.compareTo(lookbackStartStr) > 0) {
        effectiveStartDate = appStartDateStr;
      }

      const overdueWhere =
          "isDone = 0 AND dueDate IS NOT NULL AND dueDate != '' AND dueDate < ? AND dueDate >= ?";
      final overdueArgs = [todayStr, effectiveStartDate];

      // Count total overdue
      int totalOverdue = 0;
      final countRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM simple_tasks WHERE $overdueWhere',
        overdueArgs,
      );
      if (countRes.isNotEmpty) {
        totalOverdue = (countRes.first['cnt'] as num?)?.toInt() ?? 0;
      }

      final overdueRows = await db.query(
        'simple_tasks',
        where: overdueWhere,
        whereArgs: overdueArgs,
        orderBy: 'dueDate DESC, isImportant DESC',
        limit: 20, // Cap at 20 overdue tasks
      );
      for (final r in overdueRows) {
        taskIds.add(r['id'].toString());
      }

      // 4) Step counts for all loaded tasks
      final stepCounts = <String, ({int done, int total})>{};
      if (taskIds.isNotEmpty) {
        final placeholders = List.filled(taskIds.length, '?').join(',');
        final stepRows = await db.rawQuery('''
          SELECT taskId, 
                 SUM(CASE WHEN isCompleted = 1 THEN 1 ELSE 0 END) as doneCount,
                 COUNT(*) as totalCount
          FROM task_steps
          WHERE taskId IN ($placeholders)
          GROUP BY taskId
        ''', taskIds.toList());

        for (final sr in stepRows) {
          final tId = sr['taskId'].toString();
          final doneC = (sr['doneCount'] as num?)?.toInt() ?? 0;
          final totalC = (sr['totalCount'] as num?)?.toInt() ?? 0;
          stepCounts[tId] = (done: doneC, total: totalC);
        }
      }

      return TaskAgendaSource(
        tasksByDate: tasksByDate,
        overdueTasks: overdueRows,
        datelessTasks: datelessRows,
        totalOverdueCount: totalOverdue,
        stepCounts: stepCounts,
      );
    } catch (e, st) {
      RitmoLog.error('TaskAgendaSource', 'Load failed', e, st);
      return TaskAgendaSource(
        tasksByDate: const {},
        overdueTasks: const [],
        datelessTasks: const [],
        totalOverdueCount: 0,
        stepCounts: const {},
      );
    }
  }

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    if (!ctx.options.wants(AgendaDomain.task)) return [];

    final result = <AgendaItem>[];

    // 1) Regular tasks for this date
    final dayRows = tasksByDate[ctx.dateStr] ?? const [];
    for (final row in dayRows) {
      final taskId = row['id'].toString();
      final title = row['title'] as String? ?? '';
      final note = row['note'] as String?;
      final dueTime = row['dueTime'] as String?;
      final isDone = (row['isDone'] as int? ?? 0) == 1;
      final isImportant = (row['isImportant'] as int? ?? 0) == 1;
      final steps = stepCounts[taskId];

      String? subtitle;
      if (steps != null && steps.total > 0) {
        subtitle =
            '${toPersianDigits(steps.done)} از ${toPersianDigits(steps.total)}';
      } else if (note != null && note.trim().isNotEmpty) {
        final trimmed = note.trim();
        subtitle = trimmed.length > 50
            ? '${trimmed.substring(0, 50)}…'
            : trimmed;
      }

      result.add(
        AgendaItem(
          id: buildAgendaItemId(AgendaDomain.task, taskId, ctx.dateStr),
          domain: AgendaDomain.task,
          kind: AgendaItemKind.task,
          sourceId: taskId,
          title: title,
          subtitle: subtitle,
          dateStr: ctx.dateStr,
          timeOfDay: dueTime,
          durationMinutes: null,
          category: Category.personal,
          completion: isDone ? AgendaCompletion.done : AgendaCompletion.pending,
          priority: isImportant ? 2.0 : 1.0,
          isEssential: false,
          deepLink: AgendaDeepLink(domain: AgendaDomain.task, targetId: taskId),
          meta: {
            'taskRow': row,
            'stepsDone': steps?.done ?? 0,
            'stepsTotal': steps?.total ?? 0,
            'isImportant': isImportant,
          },
        ),
      );
    }

    // 2) Dateless tasks (ONLY on today, M2-7)
    if (ctx.isToday && datelessTasks.isNotEmpty) {
      for (final row in datelessTasks) {
        final taskId = row['id'].toString();
        final title = row['title'] as String? ?? '';
        final note = row['note'] as String?;
        final isImportant = (row['isImportant'] as int? ?? 0) == 1;
        final steps = stepCounts[taskId];

        String? subtitle = 'بدون تاریخ مشخص';
        if (steps != null && steps.total > 0) {
          subtitle =
              '${toPersianDigits(steps.done)} از ${toPersianDigits(steps.total)} (بدون تاریخ)';
        } else if (note != null && note.trim().isNotEmpty) {
          final trimmed = note.trim();
          subtitle = trimmed.length > 40
              ? '${trimmed.substring(0, 40)}…'
              : trimmed;
        }

        result.add(
          AgendaItem(
            id: 'task:$taskId:dateless:${ctx.dateStr}',
            domain: AgendaDomain.task,
            kind: AgendaItemKind.task,
            sourceId: taskId,
            title: title,
            subtitle: subtitle,
            dateStr: ctx.dateStr,
            timeOfDay: null,
            durationMinutes: null,
            category: Category.personal,
            itemType: AgendaItemType.floating,
            completion: AgendaCompletion.pending,
            priority: isImportant ? 1.8 : 0.9,
            isEssential: false,
            deepLink: AgendaDeepLink(
              domain: AgendaDomain.task,
              targetId: taskId,
            ),
            meta: {
              'taskRow': row,
              'isDateless': true,
              'isImportant': isImportant,
            },
          ),
        );
      }
    }

    // 3) Overdue tasks (Only on today, M2-7)
    if (ctx.isToday && overdueTasks.isNotEmpty) {
      for (final row in overdueTasks) {
        final taskId = row['id'].toString();
        final title = row['title'] as String? ?? '';
        final origDateStr = row['dueDate'] as String? ?? '';
        final isImportant = (row['isImportant'] as int? ?? 0) == 1;

        String jalaliSubtitle = 'معوقه از $origDateStr';
        try {
          final dt = DateKey.parse(origDateStr);
          if (dt != null) {
            final j = Jalali.fromDateTime(dt);
            jalaliSubtitle =
                'معوقه از ${toPersianDigits(j.day)} ${j.formatter.mN}';
          }
        } catch (e, st) {
          RitmoLog.error('TaskAgendaSource', 'overdue date parse failed', e, st);
        }

        result.add(
          AgendaItem(
            // Exception: overdue tasks deliberately have a distinct ID pattern.
            id: 'task:$taskId:overdue:${ctx.dateStr}',
            domain: AgendaDomain.task,
            kind: AgendaItemKind.task,
            sourceId: taskId,
            title: title,
            subtitle: jalaliSubtitle,
            dateStr: ctx.dateStr,
            timeOfDay: null,
            durationMinutes: null,
            category: Category.personal,
            completion: AgendaCompletion.overdue,
            priority: 3.0,
            isEssential: false,
            deepLink: AgendaDeepLink(
              domain: AgendaDomain.task,
              targetId: taskId,
            ),
            meta: {
              'taskRow': row,
              'isOverdue': true,
              'originalDueDate': origDateStr,
              'isImportant': isImportant,
            },
          ),
        );
      }

      // Overflow card for overdue tasks (M2-7)
      final remaining = totalOverdueCount - overdueTasks.length;
      if (remaining > 0) {
        result.add(
          AgendaItem(
            id: 'task:overdue_overflow:${ctx.dateStr}',
            domain: AgendaDomain.task,
            kind: AgendaItemKind.task,
            sourceId: 'overdue_overflow',
            title: '${toPersianDigits(remaining)} مورد دیگر از کارهای معوقه',
            subtitle: 'برای مشاهده همه کارهای معوقه به بخش کارها بروید',
            dateStr: ctx.dateStr,
            timeOfDay: null,
            durationMinutes: null,
            category: Category.personal,
            itemType: AgendaItemType.flexible,
            completion: AgendaCompletion.overdue,
            priority: 0.1,
            isEssential: false,
            deepLink: const AgendaDeepLink(
              domain: AgendaDomain.task,
              targetId: 'tasks_all',
            ),
            meta: {'isOverdueOverflow': true, 'remainingCount': remaining},
          ),
        );
      }
    }

    return result;
  }
}
