import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/personas/assistant_charters.dart';
import 'package:ritmo/core/ai/personas/persona_inference_profile.dart';
import 'package:ritmo/core/ai/personas/persona_skill.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/domain/commands/commands_registry.dart';
import 'package:ritmo/core/domain/commands/ritmo_command_bus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerAllRitmoCommands();
    PersonaRegistry.instance.initStandardPersonas();
  });

  group('Persona Invariants Tests', () {
    test('invariant 1 charter key exists and is non-empty', () {
      final personas = PersonaRegistry.instance.allPersonas;
      expect(personas, isNotEmpty);

      for (final p in personas) {
        expect(
          AssistantCharters.charters.containsKey(p.systemPromptKey),
          isTrue,
          reason: 'Persona "${p.id}" refers to missing charter key "${p.systemPromptKey}"',
        );

        final charterText = AssistantCharters.charters[p.systemPromptKey] ?? '';
        expect(
          charterText.length,
          greaterThan(200),
          reason: 'Charter for persona "${p.id}" with key "${p.systemPromptKey}" is too short (${charterText.length} chars)',
        );
      }
    });

    test('invariant 2 no orphan charter', () {
      final declaredKeys = AssistantCharters.charters.keys.toSet();
      final consumedKeys = PersonaRegistry.instance.allPersonas.map((p) => p.systemPromptKey).toSet();
      final orphanKeys = declaredKeys.difference(consumedKeys);

      expect(
        orphanKeys,
        isEmpty,
        reason: 'Found orphan charter keys without consuming persona: $orphanKeys',
      );
    });

    test('invariant 3 explicit inference profile for all personas', () {
      final personas = PersonaRegistry.instance.allPersonas;
      for (final p in personas) {
        expect(
          PersonaInferenceProfile.hasExplicitProfile(p.id),
          isTrue,
          reason: 'Persona "${p.id}" does not have an explicit inference profile case',
        );
      }
    });

    test('invariant 4 skill catalog covers every persona', () {
      final personas = PersonaRegistry.instance.allPersonas;

      for (final p in personas) {
        expect(
          PersonaSkill.catalogPersonaIds.contains(p.id),
          isTrue,
          reason: 'Persona "${p.id}" missing from PersonaSkill catalog',
        );

        final skills = PersonaSkill.getSkillsForPersona(p.id, null);
        expect(
          skills,
          isNotEmpty,
          reason: 'Persona "${p.id}" has empty skills list',
        );
      }
    });

    test('invariant 6 command touches must be within persona reads', () {
      final exemptCommandIds = {'assistant.handoff', 'app.openPage', 'setting.update'};
      final personas = PersonaRegistry.instance.allPersonas;

      for (final p in personas) {
        final availableCommands = RitmoCommandBus.instance.availableFor(p.id);
        for (final cmd in availableCommands) {
          if (exemptCommandIds.contains(cmd.id)) continue;
          final illegalDomains = cmd.touches.difference(p.reads);
          expect(
            illegalDomains,
            isEmpty,
            reason: 'Persona "${p.id}" has command "${cmd.id}" touching domains $illegalDomains not in reads ${p.reads} (expected green in PSN-33)',
          );
        }
      }
    });

    test('invariant 7 all persona command ids are registered', () {
      final personas = PersonaRegistry.instance.allPersonas;
      final registered = RitmoCommandBus.instance.registeredCommandIds;

      for (final p in personas) {
        final unregistered = p.commandIds.difference(registered);
        expect(
          unregistered,
          isEmpty,
          reason: 'Persona "${p.id}" contains unregistered command IDs: $unregistered',
        );
      }
    });
  });
}
