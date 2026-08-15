import 'package:flutter/foundation.dart' hide Category;
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:sqflite/sqflite.dart';

/// AgendaSource for Goal Steps domain (`goal_steps` table).
class GoalStepsAgendaSource implements AgendaSource {
  const GoalStepsAgendaSource({
    required this.goalStepsByDate,
    this.isEnabled = true,
  });

  factory GoalStepsAgendaSource.disabled() =>
      const GoalStepsAgendaSource(goalStepsByDate: {}, isEnabled: false);

  /// Returns an empty source (fallback on load failure).
  static GoalStepsAgendaSource empty() =>
      const GoalStepsAgendaSource(goalStepsByDate: {});

  final Map<String, List<Map<String, dynamic>>> goalStepsByDate;

  @override
  final bool isEnabled;

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.goalStep};

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
        ORDER BY gs.scheduledDate ASC, gs.orderIndex ASC
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

    return GoalStepsAgendaSource(goalStepsByDate: goalStepsByDate);
  }

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    if (!isEnabled || !ctx.options.wants(AgendaDomain.goalStep)) {
      return const [];
    }

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
