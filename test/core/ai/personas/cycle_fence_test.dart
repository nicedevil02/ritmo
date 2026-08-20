import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/brief/domain_brief.dart';
import 'package:ritmo/core/ai/personas/persona_response_validator.dart';
import 'package:ritmo/core/ai/brief/briefs/sleep_brief.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/domain/commands/commands_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerAllRitmoCommands();
    PersonaRegistry.instance.initStandardPersonas();
  });

  group('Cycle Privacy Fence Tests (PSN-23)', () {
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

    test('Allows "چرخهٔ خواب" in sleep persona', () {
      final sleepPersona = PersonaRegistry.instance.getPersona('sleep')!;
      const res = ParsedAssistantResponse(
        reply: 'چرخهٔ خواب و بیداری شما منظم‌تر شده است.',
        confidence: BriefConfidence.medium,
      );

      final result = validator.validate(
        res: res,
        persona: sleepPersona,
        brief: brief,
        manifestCommandIds: ['sleep.log'],
      );

      expect(result.isValid, isTrue);
    });

    test('Allows "سیکل تمرینی" in sports persona', () {
      final sportsPersona = PersonaRegistry.instance.getPersona('sports')!;
      const res = ParsedAssistantResponse(
        reply: 'سیکل تمرینی این هفته شامل ۳ جلسه ریکاوری است.',
        confidence: BriefConfidence.medium,
      );

      final result = validator.validate(
        res: res,
        persona: sportsPersona,
        brief: brief,
        manifestCommandIds: ['app.openPage'],
      );

      expect(result.isValid, isTrue);
    });

    test('Blocks menstrual keywords in global persona reply', () {
      final globalPersona = PersonaRegistry.instance.getPersona('global')!;
      const res = ParsedAssistantResponse(
        reply: 'آیا علائم قاعدگی را ثبت کرده‌اید؟',
        confidence: BriefConfidence.medium,
      );

      final result = validator.validate(
        res: res,
        persona: globalPersona,
        brief: brief,
        manifestCommandIds: ['app.openPage'],
      );

      expect(result.isValid, isFalse);
      expect(result.severity, equals(ValidationSeverity.block));
      expect(result.reason, equals('privacy_fence_cycle'));
    });

    test('Blocks menstrual keywords in command labelFa in non-cycle persona', () {
      final globalPersona = PersonaRegistry.instance.getPersona('global')!;
      const res = ParsedAssistantResponse(
        reply: 'صفحه را باز می‌کنم.',
        confidence: BriefConfidence.medium,
        commands: [
          ParsedCommand(id: 'app.openPage', payload: {}, labelFa: 'ثبت پریود و علائم'),
        ],
      );

      final result = validator.validate(
        res: res,
        persona: globalPersona,
        brief: brief,
        manifestCommandIds: ['app.openPage'],
      );

      expect(result.isValid, isFalse);
      expect(result.severity, equals(ValidationSeverity.block));
      expect(result.reason, equals('privacy_fence_cycle'));
    });

    test('Allows menstrual keywords in cycle persona', () {
      final cyclePersona = PersonaRegistry.instance.getPersona('cycle')!;
      const res = ParsedAssistantResponse(
        reply: 'بر اساس علائم قاعدگی ثبت‌شده، نوشیدن آب بیشتر توصیه می‌شود.',
        confidence: BriefConfidence.medium,
      );

      final result = validator.validate(
        res: res,
        persona: cyclePersona,
        brief: brief,
        manifestCommandIds: ['app.openPage'],
      );

      expect(result.isValid, isTrue);
    });
  });
}
