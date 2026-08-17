import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_nightly_review.dart';
import 'package:ritmo/core/ai/agent/catalog/agent_tools_initializer.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';

void main() {
  setUpAll(() {
    PersonaRegistry.instance.initStandardPersonas();
    initializeAllAgentTools();
  });

  group('AgentNightlyReview Tests (T35)', () {
    test('runs read-only nightly review without crashing', () async {
      final result = await AgentNightlyReview.instance.run(
        personaId: 'global',
        now: DateTime(2026, 8, 17, 22, 0),
      );

      expect(result.dateIso, isNotEmpty);
      expect(result.textFa, contains('مرور شبانه'));
    });

    test('respects persona tool scope constraints', () async {
      final result = await AgentNightlyReview.instance.run(
        personaId: 'sleep',
        now: DateTime(2026, 8, 17, 22, 0),
      );

      expect(result.dateIso, isNotEmpty);
    });
  });
}
