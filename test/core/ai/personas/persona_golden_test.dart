import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/ai/personas/persona_prompt_builder.dart';
import 'package:ritmo/core/ai/personas/persona_response_validator.dart';
import 'package:ritmo/core/ai/personas/persona_inference_profile.dart';
import 'package:ritmo/core/ai/brief/briefs/sleep_brief.dart';
import 'package:ritmo/core/ai/brief/domain_brief.dart';

import 'package:ritmo/core/domain/commands/commands_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerAllRitmoCommands();
    PersonaRegistry.instance.initStandardPersonas();
  });

  group('Persona Golden Tests — Prompt 070', () {
    setUp(() {
      PersonaRegistry.instance.initStandardPersonas();
    });

    test('All registered personas must contain assistant.handoff and app.openPage in commandIds', () {
      final personas = PersonaRegistry.instance.allPersonas;
      expect(personas.length, equals(13));

      for (final persona in personas) {
        expect(
          persona.commandIds.contains('assistant.handoff'),
          isTrue,
          reason: '${persona.id} missing assistant.handoff',
        );
        expect(
          persona.commandIds.contains('app.openPage'),
          isTrue,
          reason: '${persona.id} missing app.openPage',
        );
      }

      expect(
        PersonaRegistry.instance.getPersona('global')!.commandIds.length,
        greaterThan(2),
        reason: 'global persona must have registered commands',
      );
    });

    test('PersonaPromptBuilder must output all 5 layers correctly', () {
      final personas = PersonaRegistry.instance.allPersonas;

      for (final persona in personas) {
        final prompt = PersonaPromptBuilder.buildPrompt(
          persona: persona,
          todayJalali: '1405/05/19',
          briefJson: '{"confidence": "medium"}',
          memoryBlock: 'User memory preference',
        );

        // Layer 0 Core Policy
        expect(prompt, contains('صداقت شناختی'));

        // Layer 1 Expert Charter
        expect(prompt, contains('── تخصص تو ──'));

        // Skills Manifest
        expect(prompt, contains('── مهارت‌های تو ──'));
        expect(prompt, contains('فیلد `skill` در خروجی'));

        // Layer 2 Commands Manifest
        expect(prompt, contains('── فرمان‌های مجاز ──'));

        // Handoff Directory
        expect(prompt, contains('── راهنمای واگذاری (handoff) ──'));

        // Layer 3 Brief
        expect(prompt, contains('<brief>'));
        expect(prompt, contains('</brief>'));

        // Layer 4 Memory
        expect(prompt, contains('<memory>'));
        expect(prompt, contains('</memory>'));
      }
    });

    test('PersonaInferenceProfile must return explicit profiles for all personas', () {
      for (final persona in PersonaRegistry.instance.allPersonas) {
        final profile = PersonaInferenceProfile.getProfile(persona.id);
        expect(profile.maxTokens, greaterThan(0));
        expect(profile.temperature, greaterThanOrEqualTo(0.0));
      }
    });

    group('PersonaResponseValidator anti-hallucination guardrails', () {
      late PersonaResponseValidator validator;
      late SleepBrief brief;

      setUp(() {
        validator = PersonaResponseValidator();
        brief = SleepBrief(
          sampleSize: 10,
          computedAt: DateTime.now(),
          avgDurationMinutes: 420,
          avgQuality: 4.0,
          sleepDebtMinutes: 60,
          consistencyScore: 80,
        );
      });

      test('validates clean valid response', () {
        final persona = PersonaRegistry.instance.getPersona('sleep')!;
        const res = ParsedAssistantResponse(
          reply: 'بر اساس اطلاعات خواب شما، الگوی خواب منظم است.',
          confidence: BriefConfidence.medium,
          usedFields: ['sleep.consistencyScore'],
        );

        final result = validator.validate(
          res: res,
          persona: persona,
          brief: brief,
          manifestCommandIds: ['sleep.log', 'app.openPage', 'assistant.handoff'],
        );

        expect(result.isValid, isTrue);
      });

      test('rejects causal language', () {
        final persona = PersonaRegistry.instance.getPersona('sleep')!;
        const res = ParsedAssistantResponse(
          reply: 'کمبود خواب باعث شد انرژی شما افت کند.',
          confidence: BriefConfidence.medium,
        );

        final result = validator.validate(
          res: res,
          persona: persona,
          brief: brief,
          manifestCommandIds: ['sleep.log'],
        );

        expect(result.isValid, isFalse);
        expect(result.reason, equals('causal_language'));
      });

      test('rejects Gregorian dates', () {
        final persona = PersonaRegistry.instance.getPersona('sleep')!;
        const res = ParsedAssistantResponse(
          reply: 'در تاریخ 2026-08-10 خواب خوبی داشتید.',
          confidence: BriefConfidence.medium,
        );

        final result = validator.validate(
          res: res,
          persona: persona,
          brief: brief,
          manifestCommandIds: ['sleep.log'],
        );

        expect(result.isValid, isFalse);
        expect(result.reason, equals('gregorian_date'));
      });

      test('enforces privacy fence for cycle terms in non-cycle personas', () {
        final globalPersona = PersonaRegistry.instance.getPersona('global')!;
        const res = ParsedAssistantResponse(
          reply: 'امروز وضعیت علائم قاعدگی شما چطور است؟',
          confidence: BriefConfidence.medium,
        );

        final result = validator.validate(
          res: res,
          persona: globalPersona,
          brief: brief,
          manifestCommandIds: ['app.openPage'],
        );

        expect(result.isValid, isFalse);
        expect(result.reason, equals('privacy_fence_cycle'));
      });
    });
  });
}
