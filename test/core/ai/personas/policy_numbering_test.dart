import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/personas/assistant_charters.dart';
import 'package:ritmo/core/ai/personas/policy_rule_ids.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

void main() {
  group('Policy Rule Numbering Tests (PSN-10)', () {
    test(
      'AssistantCorePolicy output numbers are continuous from 1 to 16 without gaps',
      () {
        final policy = AssistantCorePolicy.build(
          personaDisplayName: 'دستیار آزمایشی',
          todayJalali: '1405/05/19',
        );

        final expectedRules = [
          PolicyRule.language,
          PolicyRule.tone,
          PolicyRule.depth,
          PolicyRule.generalKnowledge,
          PolicyRule.correlationOnly,
          PolicyRule.noFakeNumbers,
          PolicyRule.softCertainty,
          PolicyRule.noNegativeLabels,
          PolicyRule.noMedicalClaims,
          PolicyRule.stayInScope,
          PolicyRule.noFakeActions,
          PolicyRule.jsonSchema,
          PolicyRule.commandsFromManifestOnly,
          PolicyRule.emptyCommandsWhenUnsure,
          PolicyRule.jalaliInReply,
          PolicyRule.cycleFence,
        ];

        for (int i = 1; i <= 16; i++) {
          expect(
            expectedRules.contains(i),
            isTrue,
            reason: 'Rule index $i not mapped in PolicyRule',
          );
          final faDigit = PersianDigits.toFa(i.toString());
          expect(
            policy.contains('$faDigit.'),
            isTrue,
            reason:
                'AssistantCorePolicy is missing numbered rule $i ("$faDigit.")',
          );
        }
      },
    );
  });
}
