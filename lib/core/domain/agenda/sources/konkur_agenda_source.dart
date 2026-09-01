import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/features/konkur/logic/konkur_repository.dart';
import 'package:ritmo/features/konkur/models/konkur_models.dart';

class KonkurAgendaSource implements AgendaSource {
  final Map<String, List<KonkurPlanItem>> konkurByDate;
  final Map<String, String> konkurSubjectNames;
  final Map<String, String> konkurTopicNames;
  final bool konkurEnabled;

  const KonkurAgendaSource({
    required this.konkurByDate,
    required this.konkurSubjectNames,
    this.konkurTopicNames = const {},
    required this.konkurEnabled,
  });

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.konkur};

  @override
  bool get isEnabled => konkurEnabled;

  /// Returns an empty, disabled source (fallback when module is off or load fails).
  static KonkurAgendaSource disabled() => const KonkurAgendaSource(
    konkurByDate: {},
    konkurSubjectNames: {},
    konkurTopicNames: {},
    konkurEnabled: false,
  );

  static Future<KonkurAgendaSource> load(bool konkurEnabled) async {
    final konkurByDate = <String, List<KonkurPlanItem>>{};
    final konkurSubjectNames = <String, String>{};
    final konkurTopicNames = <String, String>{};

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
          final topics = await repo.getTopics();
          for (final t in topics) {
            konkurTopicNames[t.id] = t.name;
          }
        }
      } catch (e, st) {
        RitmoLog.error('KonkurAgendaSource', 'Load konkur plans failed', e, st);
      }
    }

    return KonkurAgendaSource(
      konkurByDate: konkurByDate,
      konkurSubjectNames: konkurSubjectNames,
      konkurTopicNames: konkurTopicNames,
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

      final subjectName = item.subjectId != null
          ? konkurSubjectNames[item.subjectId]
          : null;
      final topicName = item.topicId != null
          ? konkurTopicNames[item.topicId]
          : null;

      // Mode label mapping (STUDY -> مطالعه, TEST -> تست, REVIEW -> مرور)
      String? modeLabel;
      switch (item.plannedMode?.toUpperCase()) {
        case 'STUDY':
          modeLabel = 'مطالعه';
          break;
        case 'TEST':
          modeLabel = 'تست';
          break;
        case 'REVIEW':
          modeLabel = 'مرور';
          break;
      }

      // Title: topic is prominent; fallback to subject name or generic study label
      final title = (topicName != null && topicName.trim().isNotEmpty)
          ? topicName.trim()
          : ((subjectName != null && subjectName.trim().isNotEmpty)
              ? subjectName.trim()
              : 'برنامه مطالعه');

      // Subtitle: combine subject (if topic is title), duration, and study mode
      final subtitleParts = <String>[];
      if (topicName != null &&
          topicName.trim().isNotEmpty &&
          subjectName != null &&
          subjectName.trim().isNotEmpty) {
        subtitleParts.add(subjectName.trim());
      }
      if (item.plannedMinutes > 0) {
        subtitleParts.add('${item.plannedMinutes} دقیقه');
      }
      if (modeLabel != null) {
        subtitleParts.add(modeLabel);
      }
      final subtitle = subtitleParts.isNotEmpty
          ? subtitleParts.join(' · ')
          : null;

      return AgendaItem(
        id: buildAgendaItemId(AgendaDomain.konkur, item.id, ctx.dateStr),
        domain: AgendaDomain.konkur,
        sourceId: item.id,
        title: title,
        subtitle: subtitle,
        dateStr: ctx.dateStr,
        durationMinutes: item.plannedMinutes > 0 ? item.plannedMinutes : null,
        category: Category.konkur,
        completion: completion,
        priority: 1.2,
        deepLink: AgendaDeepLink(
          domain: AgendaDomain.konkur,
          targetId: item.id,
        ),
        meta: {
          'planItem': item.toMap(),
          'subjectId': item.subjectId,
          'topicId': item.topicId,
          'subjectName': subjectName,
          'topicName': topicName,
          'plannedMode': item.plannedMode,
        },
      );
    }).toList();
  }
}
