import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/brief/domain_brief.dart';
import 'package:ritmo/core/ai/personas/date_contract.dart';
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

  group('Date Contract Tests (PSN-24)', () {
    test('Converts Gregorian date in text to Jalali with Persian digits', () {
      const text = 'در تاریخ 2026-08-10 خواب خوبی داشتید.';
      final sanitized = DateContract.sanitizeGregorianToJalali(text);
      expect(sanitized.contains('2026-08-10'), isFalse);
      expect(sanitized.contains('۱۴۰۵'), isTrue);
    });

    test('Converts Jalali to ISO-8601', () {
      final iso = DateContract.jalaliToIso('1405/05/19');
      expect(iso, equals('2026-08-10'));
    });

    test(
      'Validator sanitizes Gregorian in reply while leaving ISO date in command payload intact',
      () {
        final sleepPersona = PersonaRegistry.instance.getPersona('sleep')!;
        final validator = PersonaResponseValidator();
        final brief = SleepBrief(
          sampleSize: 10,
          computedAt: DateTime.now(),
          avgDurationMinutes: 420,
          avgQuality: 4.0,
          sleepDebtMinutes: 60,
          consistencyScore: 80,
        );

        const res = ParsedAssistantResponse(
          reply: 'در تاریخ 2026-08-10 ثبت شد.',
          confidence: BriefConfidence.medium,
          commands: [
            ParsedCommand(
              id: 'sleep.log',
              payload: {'date': '2026-08-10', 'duration': 480},
              labelFa: 'ثبت خواب',
            ),
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
        expect(result.sanitizedResponse!.reply, isNot(contains('2026-08-10')));
        expect(
          result.sanitizedResponse!.commands!.first.payload['date'],
          equals('2026-08-10'),
        );
      },
    );
  });
}
