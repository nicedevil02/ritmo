import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/personas/assistant_charters.dart';
import 'package:ritmo/core/ai/personas/persona_inference_profile.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/domain/commands/commands_registry.dart';

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
      final allPersonaKeys = PersonaRegistry.instance.allPersonas.map((p) => p.systemPromptKey).toSet();
      final allCharterKeys = AssistantCharters.charters.keys.toSet();
      final orphanKeys = allCharterKeys.difference(allPersonaKeys);

      expect(
        orphanKeys,
        isEmpty,
        reason: 'Found orphan charter keys without consuming persona: $orphanKeys (expected green in PSN-38)',
      );
    });

    test('invariant 3 explicit inference profile for all personas', () {
      final personas = PersonaRegistry.instance.allPersonas;

      for (final p in personas) {
        expect(
          PersonaInferenceProfile.hasExplicitProfile(p.id),
          isTrue,
          reason: 'Persona "${p.id}" does not have an explicit inference profile case (expected green in PSN-35)',
        );
      }
    });
  });
}
