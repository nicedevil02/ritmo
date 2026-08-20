import 'package:ritmo/core/ai/brief/domain_brief.dart';
import 'package:ritmo/core/ai/personas/persona_skill_registry.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';

class PersonaSkill {
  const PersonaSkill({
    required this.id,
    required this.labelFa,
    required this.queryPrompt,
    required this.isRelevant,
    this.priority = 0,
    this.requiredCommandIds = const {},
    this.requiredBriefFields = const {},
  });

  factory PersonaSkill.fromDef(PersonaSkillDef def) {
    return PersonaSkill(
      id: def.id,
      labelFa: def.labelFa,
      queryPrompt: def.queryPrompt,
      isRelevant: def.isRelevant ?? (_) => true,
      priority: def.priority,
      requiredCommandIds: def.requiredCommandIds,
      requiredBriefFields: def.requiredBriefFields,
    );
  }

  final String id;
  final String labelFa;
  final String queryPrompt;
  final bool Function(DomainBrief? brief) isRelevant;
  final int priority;
  final Set<String> requiredCommandIds;
  final Set<String> requiredBriefFields;

  /// Maximum number of skill chips shown per persona in UI.
  static const int maxSkillsPerPersona = 4;

  /// Set of all persona IDs that have registered skills.
  static Set<String> get catalogPersonaIds {
    return PersonaSkillRegistry.all.map((s) => s.personaId).toSet();
  }

  /// Selects up to [maxSkillsPerPersona] deterministic skills for the given persona,
  /// filtering out skills requiring commands unavailable to the persona,
  /// prioritizing relevant skills followed by non-relevant ones by priority.
  static List<PersonaSkill> getSkillsForPersona(String personaId, DomainBrief? brief) {
    final defs = PersonaSkillRegistry.forPersona(personaId);
    if (defs.isEmpty) return const [];

    final persona = PersonaRegistry.instance.getPersona(personaId);
    final availableCommandIds = persona?.commandIds ?? const {};

    // Filter out skills whose required commands are not in persona.commandIds
    final usableDefs = defs.where((def) {
      if (def.requiredCommandIds.isNotEmpty) {
        if (!def.requiredCommandIds.every(availableCommandIds.contains)) {
          return false;
        }
      }
      return true;
    }).toList();

    if (usableDefs.isEmpty) return const [];

    final skills = usableDefs.map((d) => PersonaSkill.fromDef(d)).toList();

    final relevant = skills.where((s) => s.isRelevant(brief)).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    final nonRelevant = skills.where((s) => !s.isRelevant(brief)).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    final combined = [...relevant, ...nonRelevant];

    return combined.take(maxSkillsPerPersona).toList();
  }
}
