import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/courses/logic/course_date_contract.dart';
import 'package:ritmo/features/registry/domain/registry_entry.dart';
import 'package:ritmo/features/registry/logic/sources/registry_source.dart';
import 'package:ritmo/features/registry/presentation/utils/schedule_summary_formatter.dart';

class CourseRegistrySource implements RegistrySource {
  @override
  RegistryDomain get domain => RegistryDomain.course;

  @override
  String get moduleSettingsKey => 'module_courses_enabled';

  @override
  Future<int> count({bool includeArchived = false}) async {
    final db = await DatabaseHelper.instance.database;
    final whereClause = includeArchived ? '' : ' WHERE isArchived = 0';
    final res = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM courses$whereClause',
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  @override
  Future<List<RegistryEntry>> fetch({
    required int limit,
    required int offset,
    bool includeArchived = false,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'courses',
      where: includeArchived ? null : 'isArchived = 0',
      orderBy: 'createdAt DESC',
      limit: limit,
      offset: offset,
    );

    if (rows.isEmpty) return const [];

    final courseIds = rows.map((r) => r['id'] as String).toList();
    final placeholders = List.filled(courseIds.length, '?').join(',');
    final doneRes = await db.rawQuery(
      "SELECT courseId, COUNT(*) as cnt FROM course_sessions WHERE completionStatus = 'COMPLETED' AND courseId IN ($placeholders) GROUP BY courseId",
      courseIds,
    );

    final doneCounts = <String, int>{};
    for (final row in doneRes) {
      final cId = row['courseId'] as String?;
      final cnt = row['cnt'] as int? ?? 0;
      if (cId != null) {
        doneCounts[cId] = cnt;
      }
    }

    final todayStr = CourseDate.toDayKey(DateTime.now());

    final entries = <RegistryEntry>[];
    for (final r in rows) {
      final id = r['id'] as String;
      final title = r['title'] as String? ?? '';
      final provider = r['provider'] as String?;
      final prefTime = r['preferredTime'] as String?;
      final sessionDur = r['sessionDurationMinutes'] as int?;
      final totalSessions = r['totalSessions'] as int? ?? 0;
      final doneCount = doneCounts[id] ?? 0;

      final summary = ScheduleSummaryFormatter.format(timeOfDay: prefTime);
      final subtitle = provider != null && provider.isNotEmpty
          ? '$provider · $doneCount از $totalSessions جلسه'
          : '$doneCount از $totalSessions جلسه';

      entries.add(
        RegistryEntry(
          id: 'course:$id',
          domain: RegistryDomain.course,
          sourceId: id,
          title: title,
          subtitle: subtitle,
          scheduleSummary: summary,
          status: doneCount >= totalSessions && totalSessions > 0
              ? RegistryStatus.completed
              : RegistryStatus.active,
          agendaProxy: AgendaItem(
            id: 'course:$id',
            domain: AgendaDomain.course,
            sourceId: id,
            title: title,
            dateStr: todayStr,
            timeOfDay: prefTime,
            durationMinutes: sessionDur,
            category: Category.learning,
            deepLink: AgendaDeepLink(domain: AgendaDomain.course, targetId: id),
          ),
        ),
      );
    }

    return entries;
  }
}
