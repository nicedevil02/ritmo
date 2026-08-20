import 'package:ritmo/core/domain/personas/assistant_persona.dart';
import 'package:ritmo/core/domain/commands/command_manifest.dart';
import 'package:ritmo/core/ai/personas/assistant_charters.dart';
import 'package:ritmo/core/ai/personas/persona_skill_registry.dart';

class PersonaPromptBuilder {
  static String buildPrompt({
    required AssistantPersona persona,
    required String todayJalali,
    required String briefJson,
    required String memoryBlock,
  }) {
    final buffer = StringBuffer();

    // لایه ۰
    buffer.writeln(AssistantCorePolicy.build(
      personaDisplayName: persona.displayName,
      todayJalali: todayJalali,
    ));

    // لایه ۱
    final charter = AssistantCharters.charters[persona.systemPromptKey] ?? '';
    buffer.writeln('\n── تخصص تو ──');
    buffer.writeln(charter);

    // بند مهارت‌ها
    final skills = PersonaSkillRegistry.forPersona(persona.id);
    if (skills.isNotEmpty) {
      buffer.writeln('\n── مهارت‌های تو ──');
      for (final s in skills) {
        final reqCmds = s.requiredCommandIds.isNotEmpty
            ? ' (فرمان‌های لازم: ${s.requiredCommandIds.join(', ')})'
            : '';
        buffer.writeln('• ${s.id}: ${s.labelFa}$reqCmds');
      }
      buffer.writeln('فیلد `skill` در خروجی باید دقیقاً یکی از شناسه‌های بالا یا خالی باشد.');
    }

    // لایه ۲
    buffer.writeln('\n── فرمان‌های مجاز ──');
    buffer.writeln(CommandManifest.asPromptBlock(personaId: persona.id));

    // لایه ۳
    buffer.writeln('\n<brief>');
    buffer.writeln(briefJson);
    buffer.writeln('</brief>');

    // لایه ۴
    if (memoryBlock.isNotEmpty) {
      buffer.writeln('\n<memory>');
      buffer.writeln(memoryBlock);
      buffer.writeln('</memory>');
    }

    return buffer.toString();
  }
}
