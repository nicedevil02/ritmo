import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/catalog/system_agent_tools.dart';

void main() {
  group('HandoffToPersonaTool Tests (T36)', () {
    const tool = HandoffToPersonaTool();

    test('builds steps with correct target persona and reason', () async {
      final steps = await tool.buildSteps({
        'personaId': 'sleep',
        'reasonFa': 'پرسش درباره خواب',
      });

      expect(steps.length, 1);
      expect(steps.first.commandId, 'assistant.handoff');
      expect(steps.first.payload['personaId'], 'sleep');
      expect(steps.first.payload['reasonFa'], 'پرسش درباره خواب');
      expect(steps.first.payload['carryHistory'], isTrue);
    });

    test('builds informative summary in Persian', () {
      final summary = tool.buildSummaryFa({
        'personaId': 'sports',
        'reasonFa': 'تنظیم برنامه تمرینی',
      }, {});

      expect(summary, contains('sports'));
      expect(summary, contains('تنظیم برنامه تمرینی'));
    });
  });
}
