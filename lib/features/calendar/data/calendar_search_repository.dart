import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/utils/persian_text.dart';

/// Represents a search match across calendar/agenda sources.
class CalendarSearchHit {
  const CalendarSearchHit({
    required this.id,
    required this.sourceId,
    required this.title,
    this.subtitle,
    required this.domain,
    this.dateStr,
    this.timeOfDay,
    this.isRecurring = false,
  });

  final String id;
  final String sourceId;
  final String title;
  final String? subtitle;
  final AgendaDomain domain;
  final String? dateStr;
  final String? timeOfDay;
  final bool isRecurring;
}

/// Global Calendar Search Repository across all agenda domains.
class CalendarSearchRepository {
  CalendarSearchRepository._();
  static final CalendarSearchRepository instance = CalendarSearchRepository._();

  Future<List<CalendarSearchHit>> search(
    String query, {
    int limit = 50,
    bool includeHealth = false,
  }) async {
    final q = normalizeFa(query.trim()).toLowerCase();
    if (q.isEmpty) return [];

    final hits = <CalendarSearchHit>[];

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Search simple_tasks
      final tasks = await db.rawQuery(
        '''
        SELECT id, title, note, dueDate, dueTime, isDone
        FROM simple_tasks
        WHERE title LIKE ? OR note LIKE ?
        ORDER BY createdAt DESC
        LIMIT ?
      ''',
        ['%$q%', '%$q%', limit],
      );

      for (final row in tasks) {
        final title = row['title']?.toString() ?? '';
        final dueDate = row['dueDate']?.toString();
        hits.add(
          CalendarSearchHit(
            id: 'task:${row['id']}:${dueDate ?? 'nodate'}',
            sourceId: row['id'].toString(),
            title: title,
            subtitle: row['note']?.toString(),
            domain: AgendaDomain.task,
            dateStr: dueDate,
            timeOfDay: row['dueTime']?.toString(),
          ),
        );
      }

      // 2. Search routines
      final routines = await db.rawQuery(
        '''
        SELECT id, title, category, timeOfDay
        FROM routines
        WHERE isArchived = 0 AND (title LIKE ? OR category LIKE ?)
        LIMIT ?
      ''',
        ['%$q%', '%$q%', limit],
      );

      for (final row in routines) {
        final category = row['category']?.toString();
        final isHealthCategory =
            category == 'health' ||
            category == 'medicine' ||
            category == 'medical';
        if (isHealthCategory && !includeHealth) {
          continue;
        }

        final title = row['title']?.toString() ?? '';
        final domain = isHealthCategory
            ? AgendaDomain.medicine
            : AgendaDomain.routine;

        hits.add(
          CalendarSearchHit(
            id: 'routine:${row['id']}',
            sourceId: row['id'].toString(),
            title: title,
            subtitle: isHealthCategory ? 'سلامتی و دارو' : 'روتین',
            domain: domain,
            dateStr: null,
            timeOfDay: row['timeOfDay']?.toString(),
            isRecurring: true,
          ),
        );
      }

      // 3. Search goal_steps
      final steps = await db.rawQuery(
        '''
        SELECT gs.id, gs.title, gs.scheduledDate, g.title as goalTitle
        FROM goal_steps gs
        JOIN goals g ON gs.goalId = g.id
        WHERE gs.title LIKE ? OR g.title LIKE ?
        LIMIT ?
      ''',
        ['%$q%', '%$q%', limit],
      );

      for (final row in steps) {
        final title = row['title']?.toString() ?? '';
        final dateStr = row['scheduledDate']?.toString();
        hits.add(
          CalendarSearchHit(
            id: 'goalStep:${row['id']}:${dateStr ?? 'nodate'}',
            sourceId: row['id'].toString(),
            title: title,
            subtitle: row['goalTitle']?.toString(),
            domain: AgendaDomain.goalStep,
            dateStr: dateStr,
          ),
        );
      }

      // 4. Search course_sessions
      final sessions = await db.rawQuery(
        '''
        SELECT cs.id, cs.sessionTitle, cs.sessionNumber, cs.plannedDate, c.title as courseTitle, c.preferredTime
        FROM course_sessions cs
        JOIN courses c ON cs.courseId = c.id
        WHERE cs.sessionTitle LIKE ? OR c.title LIKE ?
        LIMIT ?
      ''',
        ['%$q%', '%$q%', limit],
      );

      for (final row in sessions) {
        final sessionTitle = row['sessionTitle']?.toString();
        final sessionNumber = row['sessionNumber']?.toString() ?? '1';
        final title = (sessionTitle != null && sessionTitle.isNotEmpty)
            ? sessionTitle
            : 'جلسه $sessionNumber';
        final dateStr = row['plannedDate']?.toString();

        hits.add(
          CalendarSearchHit(
            id: 'course:${row['id']}:${dateStr ?? 'nodate'}',
            sourceId: row['id'].toString(),
            title: title,
            subtitle: row['courseTitle']?.toString(),
            domain: AgendaDomain.course,
            dateStr: dateStr,
            timeOfDay: row['preferredTime']?.toString(),
          ),
        );
      }

      // 5. Search konkur_plan_items
      final konkurItems = await db.rawQuery(
        '''
        SELECT kp.id, kp.dateIso, kp.plannedMinutes, ks.name as subjectName
        FROM konkur_plan_items kp
        LEFT JOIN konkur_subjects ks ON kp.subjectId = ks.id
        WHERE ks.name LIKE ?
        LIMIT ?
      ''',
        ['%$q%', limit],
      );

      for (final row in konkurItems) {
        final subjectName = row['subjectName']?.toString() ?? 'برنامه کنکور';
        final plannedMin = (row['plannedMinutes'] as int?) ?? 0;
        final dateStr = row['dateIso']?.toString();

        hits.add(
          CalendarSearchHit(
            id: 'konkur:${row['id']}:${dateStr ?? 'nodate'}',
            sourceId: row['id'].toString(),
            title: subjectName,
            subtitle: plannedMin > 0 ? '$plannedMin دقیقه' : null,
            domain: AgendaDomain.konkur,
            dateStr: dateStr,
          ),
        );
      }

      // 6. Search worship_practices & debts
      final worshipPractices = await db.rawQuery(
        '''
        SELECT id, title, practiceType
        FROM worship_practices
        WHERE isArchived = 0 AND title LIKE ?
        LIMIT ?
      ''',
        ['%$q%', limit],
      );

      for (final row in worshipPractices) {
        final title = row['title']?.toString() ?? '';
        hits.add(
          CalendarSearchHit(
            id: 'worship:${row['id']}',
            sourceId: row['id'].toString(),
            title: title,
            subtitle: 'عبادت',
            domain: AgendaDomain.prayer,
            dateStr: null,
            isRecurring: true,
          ),
        );
      }

      final worshipDebts = await db.rawQuery(
        '''
        SELECT id, title, debtType, remainingCount
        FROM worship_debts
        WHERE isArchived = 0 AND title LIKE ?
        LIMIT ?
      ''',
        ['%$q%', limit],
      );

      for (final row in worshipDebts) {
        final title = row['title']?.toString() ?? '';
        final remaining = row['remainingCount']?.toString() ?? '0';
        hits.add(
          CalendarSearchHit(
            id: 'worshipDebt:${row['id']}',
            sourceId: row['id'].toString(),
            title: title,
            subtitle: 'باقی‌مانده: $remaining',
            domain: AgendaDomain.worshipDebt,
            dateStr: null,
            isRecurring: true,
          ),
        );
      }

      // 7. Search health cycle (if includeHealth == true)
      if (includeHealth) {
        final cycleLogs = await db.rawQuery(
          '''
          SELECT id, date, notes
          FROM cycle_logs
          WHERE notes LIKE ?
          LIMIT ?
        ''',
          ['%$q%', limit],
        );

        for (final row in cycleLogs) {
          final notes = row['notes']?.toString() ?? 'ثبت چرخه';
          final dateStr = row['date']?.toString();
          hits.add(
            CalendarSearchHit(
              id: 'cycle:${row['id']}:${dateStr ?? 'nodate'}',
              sourceId: row['id'].toString(),
              title: notes,
              subtitle: 'چرخه سلامتی',
              domain: AgendaDomain.cycle,
              dateStr: dateStr,
            ),
          );
        }
      }
    } catch (e, st) {
      RitmoLog.error('CalendarSearchRepository', 'Search failed', e, st);
    }

    return hits.take(limit).toList();
  }
}
