import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/brief/domain_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/sleep_brief.dart';
import 'package:ritmo/core/ai/personas/persona_response_validator.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/domain/commands/commands_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerAllRitmoCommands();
    PersonaRegistry.instance.initStandardPersonas();
  });

  group('Validator Severity Tests (PSN-21, PSN-25, PSN-26)', () {
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

    test('BLOCK level: Privacy fence violation blocks response completely', () {
      final globalPersona = PersonaRegistry.instance.getPersona('global')!;
      const res = ParsedAssistantResponse(
        reply: 'در مورد پریود و چرخهٔ ماهانه چه سوالی دارید؟',
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

    test('SANITIZE level: Out of manifest command is dropped and logged without blocking reply', () {
      final sleepPersona = PersonaRegistry.instance.getPersona('sleep')!;
      const res = ParsedAssistantResponse(
        reply: 'ساعت بیداری خود را تثبیت کنید.',
        confidence: BriefConfidence.medium,
        commands: [
          ParsedCommand(id: 'invalid.unknownCommand', payload: {}, labelFa: 'دستور نامعتبر'),
          ParsedCommand(id: 'app.openPage', payload: {'page': 'sleep'}, labelFa: 'باز کردن صفحه خواب'),
        ],
      );

      final result = validator.validate(
        res: res,
        persona: sleepPersona,
        brief: brief,
        manifestCommandIds: ['app.openPage'],
      );

      expect(result.isValid, isTrue);
      expect(result.severity, equals(ValidationSeverity.sanitize));
      expect(result.droppedCommandIds, contains('invalid.unknownCommand'));
      expect(result.sanitizedResponse!.commands!.length, equals(1));
      expect(result.sanitizedResponse!.commands!.first.id, equals('app.openPage'));
    });

    test('ANNOTATE level: Missing field in brief is annotated without blocking response', () {
      final sleepPersona = PersonaRegistry.instance.getPersona('sleep')!;
      const res = ParsedAssistantResponse(
        reply: 'تحلیل خواب بر اساس فیلد ناشناخته.',
        confidence: BriefConfidence.medium,
        usedFields: ['sleep.nonExistentField'],
      );

      final result = validator.validate(
        res: res,
        persona: sleepPersona,
        brief: brief,
        manifestCommandIds: ['app.openPage'],
      );

      expect(result.isValid, isTrue);
      expect(result.severity, equals(ValidationSeverity.annotate));
      expect(result.reason, equals('missing_field_in_brief'));
      expect(result.annotations, isNotEmpty);
    });

    test('Confidence Ceiling matrix: downgrades high to medium when brief is low, and high/medium to none when brief is none', () {
      final sleepPersona = PersonaRegistry.instance.getPersona('sleep')!;
      final noneBrief = SleepBrief(
        sampleSize: 0,
        computedAt: DateTime.now(),
        avgDurationMinutes: 0,
        avgQuality: 0,
        sleepDebtMinutes: 0,
        consistencyScore: null,
      );

      const highRes = ParsedAssistantResponse(
        reply: 'پاسخ مطمئن',
        confidence: BriefConfidence.high,
      );

      final result = validator.validate(
        res: highRes,
        persona: sleepPersona,
        brief: noneBrief,
        manifestCommandIds: ['app.openPage'],
      );

      expect(result.isValid, isTrue);
      expect(result.sanitizedResponse!.confidence, equals(BriefConfidence.none));
      expect(result.annotations, isNotEmpty);
    });

    test('PSN-39: When response contains both questions and commands, commands are sanitized (dropped)', () {
      final sleepPersona = PersonaRegistry.instance.getPersona('sleep')!;
      const res = ParsedAssistantResponse(
        reply: 'ساعت خواب مدنظرتان چند است؟',
        confidence: BriefConfidence.medium,
        questions: ['آیا ساعت خواب شما ثابت است؟'],
        commands: [
          ParsedCommand(id: 'sleep.log', payload: {}, labelFa: 'ثبت خواب'),
        ],
      );

      final result = validator.validate(
        res: res,
        persona: sleepPersona,
        brief: brief,
        manifestCommandIds: ['sleep.log'],
      );

      expect(result.isValid, isTrue);
      expect(result.severity, equals(ValidationSeverity.sanitize));
      expect(result.droppedCommandIds, contains('sleep.log'));
      expect(result.sanitizedResponse!.commands, isEmpty);
      expect(result.sanitizedResponse!.questions, isNotEmpty);
    });
  });
}
