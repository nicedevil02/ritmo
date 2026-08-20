import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/personas/assistant_charters.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/domain/commands/commands_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerAllRitmoCommands();
    PersonaRegistry.instance.initStandardPersonas();
  });

  group('Skill Registry Parity Tests (Invariant 5)', () {
    test(
      'every promised skill in charter exists in the single-source skill registry and vice-versa',
      () {
        // Will be populated and un-skipped in PSN-16 once PersonaSkillRegistry is created in PSN-11/12
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
