import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/brief/domain_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/rhythm_brief.dart';
import 'package:ritmo/core/ai/personas/persona_response_validator.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/domain/commands/commands_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerAllRitmoCommands();
    PersonaRegistry.instance.initStandardPersonas();
  });

  group('Combined Brief usedFields Validation Tests (PSN-28)', () {
    late PersonaResponseValidator validator;
    late RhythmBrief primaryBrief;

    setUp(() {
      validator = PersonaResponseValidator();
      primaryBrief = RhythmBrief(
        sampleSize: 10,
        computedAt: DateTime.now(),
        dailyCapacityMinutes: 500,
        allocatedMinutes: 200,
        activeDomainCount: 4,
      );
    });

    test(
      'Validates field from another domain when allowedFieldNames contains it',
      () {
        final globalPersona = PersonaRegistry.instance.getPersona('global')!;
        const res = ParsedAssistantResponse(
          reply: 'بر اساس اهداف فعال و خواب شما',
          confidence: BriefConfidence.medium,
          usedFields: ['goals.activeGoalsCount', 'sleep.sleepDebtMinutes'],
        );

        final allowedFields = {
          'goals.activeGoalsCount',
          'sleep.sleepDebtMinutes',
          'rhythm.dailyCapacityMinutes',
        };

        final result = validator.validate(
          res: res,
          persona: globalPersona,
          brief: primaryBrief,
          manifestCommandIds: ['app.openPage'],
          allowedFieldNames: allowedFields,
        );

        expect(result.isValid, isTrue);
        expect(result.reason, isNull);
      },
    );

    test('Annotates fictitious field not in allowedFieldNames', () {
      final globalPersona = PersonaRegistry.instance.getPersona('global')!;
      const res = ParsedAssistantResponse(
        reply: 'پاسخ با فیلد ساختگی',
        confidence: BriefConfidence.medium,
        usedFields: ['goals.nonExistentFictitiousField'],
      );

      final allowedFields = {
        'goals.activeGoalsCount',
        'rhythm.dailyCapacityMinutes',
      };

      final result = validator.validate(
        res: res,
        persona: globalPersona,
        brief: primaryBrief,
        manifestCommandIds: ['app.openPage'],
        allowedFieldNames: allowedFields,
      );

      expect(result.isValid, isTrue);
      expect(result.reason, equals('missing_field_in_brief'));
      expect(result.annotations, isNotEmpty);
    });
  });
}
