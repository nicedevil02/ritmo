import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/personas/persona_skill.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/domain/commands/commands_registry.dart';
import 'package:ritmo/core/ai/brief/briefs/sleep_brief.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerAllRitmoCommands();
    PersonaRegistry.instance.initStandardPersonas();
  });

  group('Skill Selection Tests (PSN-14 & PSN-15)', () {
    test(
      'Empty brief scenario: notes persona returns deterministic skills capped at 4 ordered by priority',
      () {
        final skills = PersonaSkill.getSkillsForPersona('notes', null);
        expect(skills.length, equals(PersonaSkill.maxSkillsPerPersona));
        expect(skills.length, equals(4));

        // Verify descending priority order
        for (int i = 0; i < skills.length - 1; i++) {
          expect(
            skills[i].priority,
            greaterThanOrEqualTo(skills[i + 1].priority),
          );
        }
      },
    );

    test(
      'Populated brief scenario: sleep debt > 60 prioritizes debt_report',
      () {
        final briefWithDebt = SleepBrief(
          sampleSize: 10,
          computedAt: DateTime.now(),
          avgDurationMinutes: 400,
          avgQuality: 3.5,
          sleepDebtMinutes: 90,
          consistencyScore: 80,
        );

        final skills = PersonaSkill.getSkillsForPersona('sleep', briefWithDebt);
        expect(skills, isNotEmpty);
        expect(skills.any((s) => s.id == 'debt_report'), isTrue);
      },
    );

    test(
      'Command gating scenario: filters out skills whose required commands are missing',
      () {
        final persona = PersonaRegistry.instance.getPersona('notes');
        expect(persona, isNotNull);

        final skills = PersonaSkill.getSkillsForPersona('notes', null);
        for (final s in skills) {
          if (s.requiredCommandIds.isNotEmpty) {
            for (final cmdId in s.requiredCommandIds) {
              expect(
                persona!.commandIds.contains(cmdId),
                isTrue,
                reason:
                    'Skill "${s.id}" requires command "$cmdId" which persona "${persona.id}" does not have',
              );
            }
          }
        }
      },
    );

    test(
      'PSN-15 scenario: confidence none treats all skills as relevant and orders by priority',
      () {
        final noneBrief = SleepBrief(
          sampleSize: 0,
          computedAt: DateTime.now(),
          avgDurationMinutes: 0,
          avgQuality: 0,
          sleepDebtMinutes: 0,
          consistencyScore: null,
        );

        final skills = PersonaSkill.getSkillsForPersona('sleep', noneBrief);
        expect(skills.length, greaterThanOrEqualTo(3));
        // First skill must be highest priority (consistency_coach with priority 10)
        expect(skills.first.id, equals('consistency_coach'));
      },
    );
  });
}
