import 'package:flutter/foundation.dart' hide Category;
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';

/// AgendaSource for Goal Steps domain.
class GoalStepsAgendaSource implements AgendaSource {
  GoalStepsAgendaSource({
    required this.goalStepsByDate,
  });

  final Map<String, List<Map<String, dynamic>>> goalStepsByDate;

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.goalStep};

  @override
  bool get isEnabled => true;

  /// Returns an empty source (fallback on load failure).
  static GoalStepsAgendaSource empty() =>
      GoalStepsAgendaSource(goalStepsByDate: const {});

  static Future<GoalStepsAgendaSource> load(
    Database db,
    DateTime start,
    DateTime end,
  ) async {
    final goalStepsByDate = <String, List<Map<String, dynamic>>>{};
    final startStr = start.toIso8601String().substring(0, 10);
    final endStr = end.toIso8601String().substring(0, 10);
    try {
      final res = await db.rawQuery('''
        SELECT gs.*, g.title as goalTitle
        FROM goal_steps gs
        JOIN goals g ON gs.goalId = g.id
        WHERE gs.scheduledDate >= ? AND gs.scheduledDate <= ? AND g.status = 'ACTIVE'
      ''', [startStr, endStr]);

      for (final row in res) {
        final dateStr = row['scheduledDate'] as String?;
        if (dateStr != null) {
          goalStepsByDate
              .putIfAbsent(dateStr, () => [])
              .add(Map<String, dynamic>.from(row));
        }
      }
    } catch (e, st) {
      debugPrint('[GoalStepsAgendaSource] Load goals error: $e\n$st');
    }

    try {
      final allocRes = await db.rawQuery('''
        SELECT a.id as allocId, a.dayKey, a.plannedMinutes, a.status as allocStatus,
               c.id as commId, c.title as commTitle, c.importance, c.workKind
        FROM planning_allocations a
        JOIN planning_commitments c ON a.commitmentId = c.id
        WHERE a.dayKey >= ? AND a.dayKey <= ? AND a.status != 'DROPPED' AND c.status != 'DROPPED'
      ''', [startStr, endStr]);
      for (final row in allocRes) {
        final dateStr = row['dayKey'] as String?;
        if (dateStr != null) {
          goalStepsByDate.putIfAbsent(dateStr, () => []).add({
            'id': row['allocId'],
            'isPlanningAllocation': true,
            'title': row['commTitle'],
            'goalTitle': 'برنامه و تعهد',
            'isCompleted': row['allocStatus'] == 'DONE' ? 1 : 0,
            'durationMinutes': row['plannedMinutes'] ?? 30,
            'scheduledDate': dateStr,
          });
        }
      }
    } catch (e, st) {
      debugPrint('[GoalStepsAgendaSource] Load planning error: $e\n$st');
    }

    return GoalStepsAgendaSource(goalStepsByDate: goalStepsByDate);
  }

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    if (!ctx.options.wants(AgendaDomain.goalStep)) return const [];

    final rows = goalStepsByDate[ctx.dateStr] ?? const [];
    if (rows.isEmpty) return const [];

    final items = <AgendaItem>[];
    for (final row in rows) {
      final stepId = row['id'] as String;
      final stepTitle = row['title'] as String? ?? 'گام هدف';
      final goalTitle = row['goalTitle'] as String? ?? 'هدف';
      final isDone = (row['isCompleted'] as int? ?? 0) == 1;
      final duration = (row['durationMinutes'] as int?) ?? 30;

      items.add(AgendaItem(
        id: buildAgendaItemId(AgendaDomain.goalStep, stepId, ctx.dateStr),
        sourceId: stepId,
        domain: AgendaDomain.goalStep,
        itemType: AgendaItemType.flexible,
        title: stepTitle,
        subtitle: goalTitle,
        dateStr: ctx.dateStr,
        durationMinutes: duration,
        category: Category.personal,
        deepLink: AgendaDeepLink(domain: AgendaDomain.goalStep, targetId: stepId),
        completion: isDone ? AgendaCompletion.done : AgendaCompletion.pending,
        meta: {'goalStep': row},
      ));
    }

    return items;
  }
}
