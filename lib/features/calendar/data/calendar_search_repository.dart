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
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final q = normalizeFa(trimmed);
    final rawQ = trimmed;
    final hits = <CalendarSearchHit>[];

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Search simple_tasks
      final tasks = await db.rawQuery(
        '''
        SELECT id, title, note, dueDate, dueTime, isDone
        FROM simple_tasks
        WHERE title LIKE ? OR note LIKE ? OR titleNormalized LIKE ? OR noteNormalized LIKE ?
        ORDER BY createdAt DESC
        LIMIT ?
      ''',
        ['%$rawQ%', '%$rawQ%', '%$q%', '%$q%', limit * 2],
      );

      for (final row in tasks) {
        final title = row['title']?.toString() ?? '';
        final note = row['note']?.toString();
        if (searchMatchFa(title, trimmed) || (note != null && searchMatchFa(note, trimmed))) {
          final dueDate = row['dueDate']?.toString();
          hits.add(
            CalendarSearchHit(
              id: 'task:${row['id']}:${dueDate ?? 'nodate'}',
              sourceId: row['id'].toString(),
              title: title,
              subtitle: note,
              domain: AgendaDomain.task,
              dateStr: dueDate,
              timeOfDay: row['dueTime']?.toString(),
            ),
          );
        }
      }

      // 2. Search routines
      final routines = await db.rawQuery(
        '''
        SELECT id, title, category, timeOfDay
        FROM routines
        WHERE isArchived = 0
        LIMIT ?
      ''',
        [limit * 3],
      );

      for (final row in routines) {
        final title = row['title']?.toString() ?? '';
        final category = row['category']?.toString() ?? '';
        final isHealthCategory =
            category == 'health' ||
            category == 'medicine' ||
            category == 'medical';
        if (isHealthCategory && !includeHealth) {
          continue;
        }

        if (searchMatchFa(title, trimmed) || searchMatchFa(category, trimmed)) {
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
      }

      // 3. Search goal_steps
      final steps = await db.rawQuery(
        '''
        SELECT gs.id, gs.title, gs.scheduledDate, g.title as goalTitle
        FROM goal_steps gs
        JOIN goals g ON gs.goalId = g.id
        LIMIT ?
      ''',
        [limit * 3],
      );

      for (final row in steps) {
        final title = row['title']?.toString() ?? '';
        final goalTitle = row['goalTitle']?.toString() ?? '';
        if (searchMatchFa(title, trimmed) || searchMatchFa(goalTitle, trimmed)) {
          final dateStr = row['scheduledDate']?.toString();
          hits.add(
            CalendarSearchHit(
              id: 'goalStep:${row['id']}:${dateStr ?? 'nodate'}',
              sourceId: row['id'].toString(),
              title: title,
              subtitle: goalTitle,
              domain: AgendaDomain.goalStep,
              dateStr: dateStr,
            ),
          );
        }
      }

      // 4. Search course_sessions
      final sessions = await db.rawQuery(
        '''
        SELECT cs.id, cs.sessionTitle, cs.sessionNumber, cs.plannedDate, c.title as courseTitle, c.preferredTime
        FROM course_sessions cs
        JOIN courses c ON cs.courseId = c.id
        LIMIT ?
      ''',
        [limit * 3],
      );

      for (final row in sessions) {
        final sessionTitle = row['sessionTitle']?.toString() ?? '';
        final courseTitle = row['courseTitle']?.toString() ?? '';
        final sessionNumber = row['sessionNumber']?.toString() ?? '1';
        final title = sessionTitle.isNotEmpty ? sessionTitle : 'جلسه $sessionNumber';

        if (searchMatchFa(title, trimmed) || searchMatchFa(courseTitle, trimmed)) {
          final dateStr = row['plannedDate']?.toString();
          hits.add(
            CalendarSearchHit(
              id: 'course:${row['id']}:${dateStr ?? 'nodate'}',
              sourceId: row['id'].toString(),
              title: title,
              subtitle: courseTitle,
              domain: AgendaDomain.course,
              dateStr: dateStr,
              timeOfDay: row['preferredTime']?.toString(),
            ),
          );
        }
      }

      // 5. Search konkur_plan_items
      final konkurItems = await db.rawQuery(
        '''
        SELECT kp.id, kp.dateIso, kp.plannedMinutes, ks.name as subjectName, kt.name as topicName
        FROM konkur_plan_items kp
        LEFT JOIN konkur_subjects ks ON kp.subjectId = ks.id
        LEFT JOIN konkur_topics kt ON kp.topicId = kt.id
        LIMIT ?
      ''',
        [limit * 3],
      );

      for (final row in konkurItems) {
        final topicName = row['topicName']?.toString();
        final subjectName = row['subjectName']?.toString();
        final matchesTopic = topicName != null && searchMatchFa(topicName, trimmed);
        final matchesSubject = subjectName != null && searchMatchFa(subjectName, trimmed);

        if (matchesTopic || matchesSubject) {
          final plannedMin = (row['plannedMinutes'] as int?) ?? 0;
          final dateStr = row['dateIso']?.toString();

          final title = (topicName != null && topicName.trim().isNotEmpty)
              ? topicName.trim()
              : (subjectName ?? 'برنامه کنکور');
          final subtitleParts = <String>[];
          if (topicName != null && topicName.isNotEmpty && subjectName != null) {
            subtitleParts.add(subjectName);
          }
          if (plannedMin > 0) {
            subtitleParts.add('$plannedMin دقیقه');
          }

          hits.add(
            CalendarSearchHit(
              id: 'konkur:${row['id']}:${dateStr ?? 'nodate'}',
              sourceId: row['id'].toString(),
              title: title,
              subtitle: subtitleParts.isNotEmpty ? subtitleParts.join(' · ') : null,
              domain: AgendaDomain.konkur,
              dateStr: dateStr,
            ),
          );
        }
      }

      // 6. Search worship_practices & debts
      final worshipPractices = await db.rawQuery(
        '''
        SELECT id, title, practiceType
        FROM worship_practices
        WHERE isArchived = 0
        LIMIT ?
      ''',
        [limit * 2],
      );

      for (final row in worshipPractices) {
        final title = row['title']?.toString() ?? '';
        if (searchMatchFa(title, trimmed)) {
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
      }

      final worshipDebts = await db.rawQuery(
        '''
        SELECT id, title, debtType, remainingCount
        FROM worship_debts
        WHERE isArchived = 0
        LIMIT ?
      ''',
        [limit * 2],
      );

      for (final row in worshipDebts) {
        final title = row['title']?.toString() ?? '';
        if (searchMatchFa(title, trimmed)) {
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
      }

      // 7. Search health cycle (if includeHealth == true)
      if (includeHealth) {
        final cycleLogs = await db.rawQuery(
          '''
          SELECT id, date, notes
          FROM cycle_logs
          LIMIT ?
        ''',
          [limit * 2],
        );

        for (final row in cycleLogs) {
          final notes = row['notes']?.toString() ?? 'ثبت چرخه';
          if (searchMatchFa(notes, trimmed)) {
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
      }
    } catch (e, st) {
      RitmoLog.error('CalendarSearchRepository', 'Search failed', e, st);
    }

    return hits.take(limit).toList();
  }
}
