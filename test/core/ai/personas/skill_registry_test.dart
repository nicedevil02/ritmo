import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/personas/assistant_charters.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/domain/commands/commands_registry.dart';
import 'package:ritmo/core/ai/personas/persona_skill_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerAllRitmoCommands();
    PersonaRegistry.instance.initStandardPersonas();
  });

  group('Skill Registry Parity Tests (Invariant 5)', () {
    test('PersonaSkillRegistry has unique IDs, at least 59 skills, and >= 3 per persona', () {
      final allSkills = PersonaSkillRegistry.all;
      expect(allSkills.length, greaterThanOrEqualTo(59));

      final seenIds = <String>{};
      for (final skill in allSkills) {
        expect(seenIds.contains(skill.id), isFalse, reason: 'Duplicate skill ID found: "${skill.id}"');
        seenIds.add(skill.id);
        expect(skill.labelFa, isNotEmpty);
        expect(skill.queryPrompt, isNotEmpty);
      }

      final personas = PersonaRegistry.instance.allPersonas;
      for (final p in personas) {
        final skillsForPersona = PersonaSkillRegistry.forPersona(p.id);
        expect(
          skillsForPersona.length,
          greaterThanOrEqualTo(3),
          reason: 'Persona "${p.id}" has fewer than 3 skills in PersonaSkillRegistry',
        );
      }
    });

    test('every promised skill in charter exists in the single-source skill registry and vice-versa', () {
      final allSkills = PersonaSkillRegistry.all;
      final registeredPersonaIds = PersonaRegistry.instance.allPersonas.map((p) => p.id).toSet();

      for (final skill in allSkills) {
        expect(registeredPersonaIds.contains(skill.personaId), isTrue,
            reason: 'Skill "${skill.id}" belongs to unregistered persona "${skill.personaId}"');

        expect(skill.queryPrompt.trim(), isNotEmpty,
            reason: 'Skill "${skill.id}" has empty queryPrompt');

        final persona = PersonaRegistry.instance.getPersona(skill.personaId)!;
        final charter = AssistantCharters.charters[persona.systemPromptKey] ?? '';
        expect(charter.contains(skill.id), isTrue,
            reason: 'Skill "${skill.id}" promised for persona "${skill.personaId}" is missing from charter key "${persona.systemPromptKey}"');
      }
    });
  });
}
