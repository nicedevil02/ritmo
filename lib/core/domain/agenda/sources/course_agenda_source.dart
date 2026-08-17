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

  /// Returns an empty, disabled source (fallback when module is off or load fails).
  static CourseAgendaSource disabled() => const CourseAgendaSource(
    courseTitles: {},
    coursesMap: {},
    sessionsByDate: {},
    coursesEnabled: false,
  );

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
          if (c.status == CourseStatus.paused || c.isArchived) continue;
          courseTitles[c.id] = c.title;
          coursesMap[c.id] = c;
        }
        final activeIds = courseTitles.keys.toSet();
        if (activeIds.isNotEmpty) {
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
        }
      } catch (e, st) {
        debugPrint('Error in course_agenda_source.dart: $e\n$st');
      }
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
    final items = <AgendaItem>[];

    for (final s in sessions) {
      final course = coursesMap[s.courseId];
      if (course != null &&
          (course.status == CourseStatus.paused || course.isArchived)) {
        continue;
      }

      // 1. Time fallback chain: session.plannedStartTime -> course.preferredTime -> null
      final resolvedTime =
          (s.plannedStartTime != null && s.plannedStartTime!.trim().isNotEmpty)
          ? s.plannedStartTime!.trim()
          : course?.preferredTime;

      // 2. Duration fallback chain: session.estimatedDurationMinutes -> course.sessionDurationMinutes -> 30
      final resolvedDuration =
          s.estimatedDurationMinutes ?? course?.sessionDurationMinutes ?? 30;

      // 3. Status mapping: completed -> done, skipped -> skipped, pending -> pending
      AgendaCompletion completion = AgendaCompletion.pending;
      if (s.completionStatus == SessionStatus.completed || s.isCompleted) {
        completion = AgendaCompletion.done;
      } else if (s.completionStatus == SessionStatus.skipped) {
        completion = AgendaCompletion.skipped;
      }

      items.add(
        AgendaItem(
          id: buildAgendaItemId(AgendaDomain.course, s.id, ctx.dateStr),
          domain: AgendaDomain.course,
          sourceId: s.id,
          title: s.sessionTitle ?? 'جلسه ${s.sessionNumber}',
          subtitle: course?.title,
          dateStr: ctx.dateStr,
          timeOfDay: resolvedTime,
          durationMinutes: resolvedDuration,
          category: Category.learning,
          itemType: resolvedTime != null
              ? AgendaItemType.fixed
              : AgendaItemType.flexible,
          completion: completion,
          priority: 1.5,
          deepLink: AgendaDeepLink(
            domain: AgendaDomain.course,
            targetId: s.courseId,
          ),
          meta: {'session': s.toMap()},
        ),
      );
    }

    return items;
  }
}
