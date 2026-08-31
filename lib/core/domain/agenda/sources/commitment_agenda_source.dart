import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:sqflite/sqflite.dart';

/// Agenda source for planning commitments and allocations (`planning_commitments` & `planning_allocations`).
class CommitmentAgendaSource implements AgendaSource {
  const CommitmentAgendaSource({
    required this.allocationsByDate,
    this.isEnabled = true,
  });

  factory CommitmentAgendaSource.disabled() =>
      const CommitmentAgendaSource(allocationsByDate: {}, isEnabled: false);

  final Map<String, List<Map<String, dynamic>>> allocationsByDate;

  @override
  final bool isEnabled;

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.commitment};

  static Future<CommitmentAgendaSource> load(
    Database db,
    DateTime start,
    DateTime end,
  ) async {
    final startStr = DateKey.of(start);
    final endStr = DateKey.of(end);
    final allocationsByDate = <String, List<Map<String, dynamic>>>{};

    try {
      final allocRes = await db.rawQuery(
        '''
        SELECT a.id as allocId, a.dayKey, a.plannedMinutes, a.timeWindowStart, a.timeWindowEnd,
               a.exactTime, a.status as allocStatus, a.materializedEntityType, a.materializedEntityId,
               c.id as commId, c.title as commTitle, c.importance, c.workKind, c.flexibility, c.goalId,
               c.sourceType, c.sourceId
        FROM planning_allocations a
        JOIN planning_commitments c ON a.commitmentId = c.id
        WHERE a.dayKey >= ? AND a.dayKey <= ? AND a.status != 'DROPPED' AND a.status != 'MOVED' AND c.status != 'DROPPED'
          AND (a.materializedEntityType IS NULL OR a.materializedEntityType != 'TASK' OR a.materializedEntityId IS NULL)
        ORDER BY a.exactTime ASC, a.timeWindowStart ASC, a.createdAt ASC
      ''',
        [startStr, endStr],
      );

      for (final row in allocRes) {
        final dateStr = row['dayKey'] as String?;
        if (dateStr != null) {
          allocationsByDate.putIfAbsent(dateStr, () => []).add(row);
        }
      }
    } catch (e, st) {
      RitmoLog.error('CommitmentAgendaSource', 'Failed to load planning allocations', e, st);
    }

    return CommitmentAgendaSource(allocationsByDate: allocationsByDate);
  }

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    if (!isEnabled || !ctx.options.wants(AgendaDomain.commitment)) {
      return const [];
    }

    final rows = allocationsByDate[ctx.dateStr] ?? const [];
    if (rows.isEmpty) return const [];

    final items = <AgendaItem>[];
    for (final row in rows) {
      final matType = row['materializedEntityType']?.toString();
      final matId = row['materializedEntityId']?.toString();
      if (matType == 'TASK' && matId != null && matId.isNotEmpty) {
        continue;
      }

      final allocId = row['allocId']?.toString() ?? '';
      final title = row['commTitle']?.toString() ?? 'برنامه و تعهد';
      final exactTime = row['exactTime']?.toString();
      final timeWindowStart = row['timeWindowStart']?.toString();
      final timeWindowEnd = row['timeWindowEnd']?.toString();
      final plannedMinutes = (row['plannedMinutes'] as int?) ?? 30;
      final allocStatus = row['allocStatus']?.toString() ?? 'PLANNED';
      if (allocStatus == 'DROPPED' || allocStatus == 'MOVED') {
        continue;
      }
      if (!ctx.options.includeCompleted && allocStatus == 'DONE') {
        continue;
      }
      final importance = row['importance']?.toString() ?? 'SHOULD';
      final workKind = row['workKind']?.toString() ?? 'LIGHT';
      final flexibility = row['flexibility']?.toString() ?? 'FLEXIBLE';

      final resolvedTime = exactTime ?? timeWindowStart;
      final isFixed = flexibility == 'FIXED' || exactTime != null;

      final startDt = _parseWindowTime(
        ctx.dateStr,
        timeWindowStart ?? exactTime,
      );
      final endDt = _parseWindowTime(ctx.dateStr, timeWindowEnd);

      items.add(
        AgendaItem(
          id: buildAgendaItemId(AgendaDomain.commitment, allocId, ctx.dateStr),
          domain: AgendaDomain.commitment,
          sourceId: allocId,
          title: title,
          dateStr: ctx.dateStr,
          timeOfDay: resolvedTime,
          durationMinutes: plannedMinutes,
          windowStart: startDt,
          windowEnd: endDt,
          category: _mapWorkKindToCategory(workKind),
          priority: _mapImportanceToPriority(importance),
          isEssential: importance == 'MUST',
          itemType: isFixed ? AgendaItemType.fixed : AgendaItemType.flexible,
          completion: allocStatus == 'DONE'
              ? AgendaCompletion.done
              : AgendaCompletion.pending,
          deepLink: AgendaDeepLink(
            domain: AgendaDomain.commitment,
            targetId: allocId,
          ),
          meta: {'allocation': row},
        ),
      );
    }

    return items;
  }

  static Category _mapWorkKindToCategory(String workKind) {
    switch (workKind.toUpperCase()) {
      case 'DEEP':
      case 'LIGHT':
        return Category.work;
      case 'ADMIN':
      case 'SOCIAL':
        return Category.personal;
      case 'RECOVERY':
        return Category.free;
      default:
        return Category.work;
    }
  }

  static double _mapImportanceToPriority(String importance) {
    switch (importance.toUpperCase()) {
      case 'MUST':
        return 2.0;
      case 'SHOULD':
        return 1.0;
      case 'COULD':
        return 0.5;
      default:
        return 1.0;
    }
  }

  static DateTime? _parseWindowTime(String date, String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    final parts = timeStr.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    final d = DateTime.tryParse(date);
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day, h, m);
  }
}
