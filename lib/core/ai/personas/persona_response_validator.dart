import 'package:ritmo/core/ai/brief/domain_brief.dart';
import 'package:ritmo/core/domain/personas/assistant_persona.dart';

class ParsedCommand {
  const ParsedCommand({required this.id, required this.payload, required this.labelFa});
  final String id;
  final Map<String, dynamic> payload;
  final String labelFa;
}

class ParsedAssistantResponse {
  const ParsedAssistantResponse({
    this.reply,
    this.skill,
    required this.confidence,
    this.usedFields,
    this.commands,
    this.handoff,
  });
  final String? reply;
  final String? skill;
  final BriefConfidence confidence;
  final List<String>? usedFields;
  final List<ParsedCommand>? commands;
  final String? handoff;
}

class ValidationResult {
  const ValidationResult({
    required this.isValid,
    this.reason,
    this.retryMessage,
    this.sanitizedResponse,
  });
  final bool isValid;
  final String? reason;
  final String? retryMessage;
  final ParsedAssistantResponse? sanitizedResponse;
}

class PersonaResponseValidator {
  ValidationResult validate({
    required ParsedAssistantResponse res,
    required AssistantPersona persona,
    required DomainBrief brief,
    required List<String> manifestCommandIds,
  }) {
    String reply = res.reply ?? '';

    // 1. Missing field in usedFields
    if (res.usedFields != null) {
      for (final f in res.usedFields!) {
        if (!brief.fieldNames.contains(f)) {
          return ValidationResult(
            isValid: false,
            reason: 'missing_field_in_brief',
            retryMessage: 'فیلد \$f در داده‌های ارسال‌شده وجود ندارد. فقط از فیلدهای موجود استفاده کن.',
          );
        }
      }
    }

    // 2. Command out of manifest (silent filter)
    final validCommands = <ParsedCommand>[];
    if (res.commands != null) {
      for (final cmd in res.commands!) {
        if (manifestCommandIds.contains(cmd.id)) {
          validCommands.add(cmd);
        } else {
          // Log out-of-manifest command
          print('Warning: Assistant attempted to use unmanifested command \${cmd.id}');
        }
      }
    }

    // 3. Causal Language
    final causalRegex = RegExp(r'(باعث شد|به خاطرِ|به‌خاطر|چون|منجر به|سبب شد)');
    if (causalRegex.hasMatch(reply)) {
      return const ValidationResult(
        isValid: false,
        reason: 'causal_language',
        retryMessage: 'قانون ۲ نقض شد. از زبان علّی استفاده کردی. لطفاً پاسخ را با استفاده از کلمات همبستگی (مثل "همراه با") بازنویسی کن.',
      );
    }

    // 4. Confidence ceiling
    BriefConfidence finalConfidence = res.confidence;
    if (brief.confidence == BriefConfidence.none && 
        (res.confidence == BriefConfidence.medium || res.confidence == BriefConfidence.high)) {
      finalConfidence = BriefConfidence.none;
      // Strip out analysis parts if possible, but simplest is to just downgrade confidence
    }

    // 5. Gregorian Date
    final dateRegex = RegExp(r'\d{4}-\d{2}-\d{2}');
    if (dateRegex.hasMatch(reply)) {
      return const ValidationResult(
        isValid: false,
        reason: 'gregorian_date',
        retryMessage: 'قانون ۱ نقض شد. استفاده از تاریخ میلادی ممنوع است. لطفاً به شمسی بازنویسی کن.',
      );
    }

    // 6. Privacy fence
    if (persona.id != 'cycle') {
      final cycleRegex = RegExp(r'(چرخه|قاعدگی|پریود|سیکل|menstrual|period|pregnancy)');
      if (cycleRegex.hasMatch(reply)) {
        return const ValidationResult(
          isValid: false,
          reason: 'privacy_fence_cycle',
          retryMessage: 'قانون ۱ (لایه صفر) نقض شد. تو مجاز به بحث درباره چرخه نیستی. این پاسخ کاملا مسدود می‌شود.',
        );
      }
    }

    return ValidationResult(
      isValid: true,
      sanitizedResponse: ParsedAssistantResponse(
        reply: reply,
        skill: res.skill,
        confidence: finalConfidence,
        usedFields: res.usedFields,
        commands: validCommands,
        handoff: res.handoff,
      ),
    );
  }
}
