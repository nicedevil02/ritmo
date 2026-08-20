import 'package:ritmo/core/ai/brief/domain_brief.dart';

/// Single-source definition of a Persona Skill.
class PersonaSkillDef {
  const PersonaSkillDef({
    required this.id,
    required this.personaId,
    required this.labelFa,
    required this.queryPrompt,
    this.priority = 0,
    this.requiredCommandIds = const {},
    this.requiredBriefFields = const {},
    this.isRelevant,
  });

  /// Stable skill ID matching the identifier in the assistant's charter.
  final String id;

  /// Owner persona ID.
  final String personaId;

  /// Farsi label for UI chips.
  final String labelFa;

  /// Query prompt sent to the model when the user taps this skill chip.
  final String queryPrompt;

  /// Priority score (higher values appear first in UI).
  final int priority;

  /// Command IDs required for execution (empty set for pure analysis skills).
  final Set<String> requiredCommandIds;

  /// Brief field paths required for this skill to be meaningful.
  final Set<String> requiredBriefFields;

  /// Optional relevancy checker given a DomainBrief. If null, considered always relevant.
  final bool Function(DomainBrief? brief)? isRelevant;
}

/// Single-source registry of all Persona skills across Ritmo.
class PersonaSkillRegistry {
  PersonaSkillRegistry._();

  /// Master list of all registered skill definitions.
  static const List<PersonaSkillDef> all = [];

  /// Returns all skills defined for the specified persona.
  static List<PersonaSkillDef> forPersona(String personaId) {
    return all.where((s) => s.personaId == personaId).toList();
  }

  /// Finds a skill definition by its unique ID.
  static PersonaSkillDef? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }
}
