import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/personas/assistant_charters.dart';
import 'package:ritmo/core/ai/personas/persona_prompt_builder.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/domain/commands/commands_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerAllRitmoCommands();
    PersonaRegistry.instance.initStandardPersonas();
  });

  test('Inspect prompt for sleep, notes, and global personas (PSN-50)', () {
    for (final personaId in ['sleep', 'notes', 'global']) {
      final persona = PersonaRegistry.instance.getPersona(personaId);
      expect(persona, isNotNull);

      final prompt = PersonaPromptBuilder.buildPrompt(
        persona: persona!,
        todayJalali: '1405/05/19',
        briefJson: '{"sample_key": "sample_value"}',
        memoryBlock: 'حافظه موقت',
      );

      // Verify all 5 layers
      expect(prompt, contains('── تخصص تو ──')); // Layer 1 (Charter)
      expect(
        prompt,
        contains(AssistantCharters.charters[persona.systemPromptKey]!),
      );
      expect(prompt, contains('── مهارت‌های تو ──')); // Layer 3 (Skills)
      expect(prompt, contains('── فرمان‌های مجاز ──')); // Layer 4 (Commands)
      expect(
        prompt,
        contains('── راهنمای واگذاری (handoff) ──'),
      ); // Handoff directory
      expect(prompt, contains('<brief>')); // Layer 2 (Brief)
      expect(prompt, contains('sample_key'));
      expect(prompt, contains('<memory>')); // Memory block

      print('=== PROMPT INSPECT: $personaId ===');
      print('Length: ${prompt.length} chars');
    }
  });
}
