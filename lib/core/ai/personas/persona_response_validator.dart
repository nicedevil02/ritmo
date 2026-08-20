import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/ai/brief/domain_brief.dart';
import 'package:ritmo/core/ai/personas/policy_rule_ids.dart';
import 'package:ritmo/core/ai/personas/validator_lexicon.dart';
import 'package:ritmo/core/ai/personas/date_contract.dart';
import 'package:ritmo/core/domain/personas/assistant_persona.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';

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

enum ValidationSeverity {
  block,
  sanitize,
  annotate,
}

class ValidationResult {
  const ValidationResult({
    required this.isValid,
    this.severity = ValidationSeverity.block,
    this.reason,
    this.retryMessage,
    this.sanitizedResponse,
    this.annotations = const [],
    this.droppedCommandIds = const [],
  });

  final bool isValid;
  final ValidationSeverity severity;
  final String? reason;
  final String? retryMessage;
  final ParsedAssistantResponse? sanitizedResponse;
  final List<String> annotations;
  final List<String> droppedCommandIds;
}

class PersonaResponseValidator {
  ValidationResult validate({
    required ParsedAssistantResponse res,
    required AssistantPersona persona,
    required DomainBrief brief,
    required List<String> manifestCommandIds,
    Set<String>? allowedFieldNames,
  }) {
    String reply = res.reply ?? '';
    final annotations = <String>[];
    final droppedCommands = <String>[];
    String? primaryReason;
    ValidationSeverity overallSeverity = ValidationSeverity.annotate;

    // 1. Privacy Fence (BLOCK)
    if (persona.id != 'cycle') {
      final hasCycleInReply = ValidatorLexicon.containsPhrase(reply, ValidatorLexicon.cyclePhrases);
      final hasCycleInCommands = res.commands?.any(
            (c) => ValidatorLexicon.containsPhrase(c.labelFa, ValidatorLexicon.cyclePhrases),
          ) ??
          false;
      final hasCycleInHandoff = res.handoff != null &&
          ValidatorLexicon.containsPhrase(res.handoff!, ValidatorLexicon.cyclePhrases);

      if (hasCycleInReply || hasCycleInCommands || hasCycleInHandoff) {
        RitmoLog.warning('PersonaResponseValidator', 'Blocked cycle privacy fence violation by persona "${persona.id}"');
        return const ValidationResult(
          isValid: false,
          severity: ValidationSeverity.block,
          reason: 'privacy_fence_cycle',
          retryMessage: 'قانون ${PolicyRule.cycleFence} (لایه صفر) نقض شد. تو مجاز به بحث درباره چرخه نیستی. این پاسخ کاملا مسدود می‌شود.',
        );
      }
    }

    // 2. Out-of-manifest Commands (SANITIZE)
    final validCommands = <ParsedCommand>[];
    if (res.commands != null) {
      for (final cmd in res.commands!) {
        if (manifestCommandIds.contains(cmd.id)) {
          validCommands.add(cmd);
        } else {
          droppedCommands.add(cmd.id);
          annotations.add('فرمان نامعتبر "${cmd.id}" حذف شد.');
          RitmoLog.warning('PersonaResponseValidator', 'Dropped unmanifested command "${cmd.id}" for persona "${persona.id}"');
          overallSeverity = ValidationSeverity.sanitize;
          primaryReason ??= 'unmanifested_command';
        }
      }
    }

    // 3. Gregorian Date in Reply (SANITIZE)
    if (DateContract.hasGregorianDate(reply)) {
      reply = DateContract.sanitizeGregorianToJalali(reply);
      annotations.add('تاریخ میلادی در متن به جلالی اصلاح شد.');
      RitmoLog.info('PersonaResponseValidator', 'Sanitized Gregorian date in reply for persona "${persona.id}"');
      overallSeverity = ValidationSeverity.sanitize;
      primaryReason ??= 'gregorian_date';
    }

    // 4. Invalid Handoff (SANITIZE)
    String? validHandoff = res.handoff;
    if (validHandoff != null && validHandoff.isNotEmpty) {
      final targetPersona = PersonaRegistry.instance.getPersona(validHandoff);
      if (targetPersona == null) {
        RitmoLog.warning('PersonaResponseValidator', 'Invalid handoff target "$validHandoff" dropped.');
        annotations.add('مقصد واگذاری نامعتبر "$validHandoff" حذف شد.');
        validHandoff = null;
        overallSeverity = ValidationSeverity.sanitize;
        primaryReason ??= 'invalid_handoff';
      }
    }

    // 5. Causal Language (ANNOTATE)
    if (ValidatorLexicon.containsPhrase(reply, ValidatorLexicon.causalPhrases, exemptQuotes: true)) {
      annotations.add('پاسخ شامل زبان علّی است و به همبستگی محدود شد.');
      RitmoLog.info('PersonaResponseValidator', 'Annotated causal language in reply for persona "${persona.id}"');
      primaryReason ??= 'causal_language';
    }

    // 6. Missing Fields in Brief (ANNOTATE)
    if (res.usedFields != null) {
      final validFieldPool = allowedFieldNames ?? brief.fieldNames;
      for (final f in res.usedFields!) {
        if (!validFieldPool.contains(f)) {
          annotations.add('فیلد "$f" در داده‌های ارسالی موجود نیست.');
          RitmoLog.warning('PersonaResponseValidator', 'Referenced field "$f" not found in valid fields pool');
          primaryReason ??= 'missing_field_in_brief';
        }
      }
    }

    // 7. Monotonic Confidence Ceiling (ANNOTATE)
    final finalConfidence = _capConfidence(res.confidence, brief.confidence);
    if (finalConfidence != res.confidence) {
      annotations.add('سطح اطمینان به دلیل محدودیت داده از ${res.confidence.name} به ${finalConfidence.name} تنظیم شد.');
      RitmoLog.info('PersonaResponseValidator', 'Downgraded confidence from ${res.confidence.name} to ${finalConfidence.name}');
      primaryReason ??= 'confidence_downgraded';
    }

    return ValidationResult(
      isValid: true,
      severity: primaryReason == null ? ValidationSeverity.annotate : overallSeverity,
      reason: primaryReason,
      annotations: annotations,
      droppedCommandIds: droppedCommands,
      sanitizedResponse: ParsedAssistantResponse(
        reply: reply,
        skill: res.skill,
        confidence: finalConfidence,
        usedFields: res.usedFields,
        commands: validCommands,
        handoff: validHandoff,
      ),
    );
  }

  /// Ensures model confidence does not exceed brief confidence.
  static BriefConfidence _capConfidence(BriefConfidence modelConf, BriefConfidence briefConf) {
    if (briefConf == BriefConfidence.none) {
      return BriefConfidence.none;
    }
    if (briefConf == BriefConfidence.low && modelConf == BriefConfidence.high) {
      return BriefConfidence.medium;
    }
    return modelConf;
  }
}
