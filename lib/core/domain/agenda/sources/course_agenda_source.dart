import 'package:flutter/foundation.dart' hide Category;
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/courses/models/course_models.dart';
import 'package:ritmo/features/courses/logic/courses_repository.dart';
import 'package:sqflite/sqflite.dart';

class CourseAgendaSource implements AgendaSource {
  final Map<String, String> courseTitles;
  final Map<String, Course> coursesMap;
  final Map<String, List<CourseSession>> sessionsByDate;
  final bool coursesEnabled;

  const CourseAgendaSource({
    required this.courseTitles,
    required this.coursesMap,
    required this.sessionsByDate,
    required this.coursesEnabled,
  });

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.course};

  @override
  bool get isEnabled => coursesEnabled;

  static Future<CourseAgendaSource> load(
    Database db,
    bool coursesEnabled,
    String startStr,
    String endStr,
  ) async {
    final courseTitles = <String, String>{};
    final coursesMap = <String, Course>{};
    final sessionsByDate = <String, List<CourseSession>>{};

    if (coursesEnabled) {
      try {
        final courses = await CoursesRepository.instance.getActiveCourses();
        for (final c in courses) {
          courseTitles[c.id] = c.title;
          coursesMap[c.id] = c;
        }
        final activeIds = courseTitles.keys.toSet();
        final sessionRows = await db.query(
          'course_sessions',
          where: 'plannedDate >= ? AND plannedDate <= ?',
          whereArgs: [startStr, endStr],
        );
        for (final row in sessionRows) {
          final session = CourseSession.fromMap(row);
          if (session.plannedDate == null) continue;
          if (!activeIds.contains(session.courseId)) continue;
          sessionsByDate
              .putIfAbsent(session.plannedDate!, () => [])
              .add(session);
        }
      } catch (e, st) { debugPrint('Error in course_agenda_source.dart: $e\n$st'); }
    }

    return CourseAgendaSource(
      courseTitles: courseTitles,
      coursesMap: coursesMap,
      sessionsByDate: sessionsByDate,
      coursesEnabled: coursesEnabled,
    );
  }

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    if (!ctx.options.wants(AgendaDomain.course)) return const [];

    final sessions = sessionsByDate[ctx.dateStr] ?? const [];
    return sessions.map((s) {
      final course = coursesMap[s.courseId];
      return AgendaItem(
        id: buildAgendaItemId(AgendaDomain.course, s.id, ctx.dateStr),
        domain: AgendaDomain.course,
        sourceId: s.id,
        title: s.sessionTitle ?? 'جلسه ${s.sessionNumber}',
        subtitle: course?.title,
        dateStr: ctx.dateStr,
        timeOfDay: course?.preferredTime,
        durationMinutes: course?.sessionDurationMinutes,
        category: Category.learning,
        completion:
            s.isCompleted ? AgendaCompletion.done : AgendaCompletion.pending,
        priority: 1.5,
        deepLink:
            AgendaDeepLink(domain: AgendaDomain.course, targetId: s.courseId),
        meta: {'session': s.toMap()},
      );
    }).toList();
  }
}
