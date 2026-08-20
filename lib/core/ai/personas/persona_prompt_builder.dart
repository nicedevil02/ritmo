import 'package:ritmo/core/domain/personas/assistant_persona.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/domain/commands/command_manifest.dart';
import 'package:ritmo/core/ai/personas/assistant_charters.dart';
import 'package:ritmo/core/ai/personas/persona_skill_registry.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';

class PersonaPromptBuilder {
  static String buildPrompt({
    required AssistantPersona persona,
    required String todayJalali,
    required String briefJson,
    required String memoryBlock,
  }) {
    final buffer = StringBuffer();

    // لایه ۰
    final isSpecialized = persona.id != 'global' && persona.id != 'general';
    buffer.writeln(AssistantCorePolicy.build(
      personaDisplayName: persona.displayName,
      todayJalali: todayJalali,
      isSpecialized: isSpecialized,
    ));

    // لایه ۱
    final charter = AssistantCharters.charters[persona.systemPromptKey];
    if (charter == null || charter.trim().isEmpty) {
      RitmoLog.error('PersonaPromptBuilder', 'Missing or empty charter for persona ${persona.id} (key: ${persona.systemPromptKey})');
      throw StateError('منشور پرسونای "${persona.id}" یافت نشد.');
    }
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

    // راهنمای واگذاری
    final otherPersonas = PersonaRegistry.instance.allPersonas
        .where((p) => p.id != persona.id)
        .toList();
    if (otherPersonas.isNotEmpty) {
      buffer.writeln('\n── راهنمای واگذاری (handoff) ──');
      buffer.writeln('اگر موضوع خارج از تخصص توست، با دستور `assistant.handoff` به یکی از این دستیاران ارجاع بده:');
      for (final other in otherPersonas) {
        final hint = other.handoffHint?.isNotEmpty == true ? ' (${other.handoffHint})' : '';
        buffer.writeln('• ${other.id}: ${other.displayName}$hint');
      }
    }

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
