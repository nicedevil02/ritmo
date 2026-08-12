import 'package:flutter/foundation.dart' hide Category;
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/konkur/models/konkur_models.dart';
import 'package:ritmo/features/konkur/logic/konkur_repository.dart';

class KonkurAgendaSource implements AgendaSource {
  final Map<String, List<KonkurPlanItem>> konkurByDate;
  final Map<String, String> konkurSubjectNames;
  final bool konkurEnabled;

  const KonkurAgendaSource({
    required this.konkurByDate,
    required this.konkurSubjectNames,
    required this.konkurEnabled,
  });

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.konkur};

  @override
  bool get isEnabled => konkurEnabled;

  static Future<KonkurAgendaSource> load(
    bool konkurEnabled,
  ) async {
    final konkurByDate = <String, List<KonkurPlanItem>>{};
    final konkurSubjectNames = <String, String>{};

    if (konkurEnabled) {
      try {
        final repo = KonkurRepository.instance;
        final plan = await repo.getPlanItems();
        for (final item in plan) {
          konkurByDate.putIfAbsent(item.dateIso, () => []).add(item);
        }
        if (konkurByDate.isNotEmpty) {
          final subjects = await repo.getSubjects();
          for (final s in subjects) {
            konkurSubjectNames[s.id] = s.name;
          }
        }
      } catch (e, st) { debugPrint('Error in konkur_agenda_source.dart: $e\n$st'); }
    }

    return KonkurAgendaSource(
      konkurByDate: konkurByDate,
      konkurSubjectNames: konkurSubjectNames,
      konkurEnabled: konkurEnabled,
    );
  }

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    if (!ctx.options.wants(AgendaDomain.konkur)) return const [];

    final plan = konkurByDate[ctx.dateStr] ?? const [];
    return plan.map((item) {
      AgendaCompletion completion;
      switch (item.status) {
        case 'DONE':
          completion = AgendaCompletion.done;
        case 'SKIPPED':
          completion = AgendaCompletion.skipped;
        default:
          completion = AgendaCompletion.pending;
      }
      final subjectName =
          item.subjectId != null ? konkurSubjectNames[item.subjectId] : null;
      return AgendaItem(
        id: buildAgendaItemId(AgendaDomain.konkur, item.id, ctx.dateStr),
        domain: AgendaDomain.konkur,
        sourceId: item.id,
        title: subjectName ?? 'برنامه کنکور',
        subtitle: item.plannedMinutes > 0 ? '${item.plannedMinutes} دقیقه' : null,
        dateStr: ctx.dateStr,
        durationMinutes: item.plannedMinutes > 0 ? item.plannedMinutes : null,
        category: Category.konkur,
        completion: completion,
        priority: 1.2,
        deepLink:
            AgendaDeepLink(domain: AgendaDomain.konkur, targetId: item.id),
        meta: {'planItem': item.toMap()},
      );
    }).toList();
  }
}
