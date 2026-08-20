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

    test(
      'every promised skill in charter exists in the single-source skill registry and vice-versa',
      () {
        // Will be populated and un-skipped in PSN-16
        final personas = PersonaRegistry.instance.allPersonas;
        for (final p in personas) {
          final charter = AssistantCharters.charters[p.systemPromptKey] ?? '';
          expect(charter, isNotEmpty);
        }
      },
      skip: 'enabled by PSN-16',
    );
  });
}
