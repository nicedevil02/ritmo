import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_tool_registry.dart';
import 'package:ritmo/core/ai/agent/agent_tool_scope.dart';
import 'package:ritmo/core/ai/agent/catalog/agent_tools_initializer.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';

void main() {
  setUpAll(() {
    PersonaRegistry.instance.initStandardPersonas();
    initializeAllAgentTools();
  });

  group('AgentToolScope 1-to-1 Parity Integrity Tests (T16)', () {
    test('every registered tool has a corresponding entry in AgentToolScope.requirements', () {
      final allTools = AgentToolRegistry.instance.allTools;
      expect(allTools, isNotEmpty);

      final missingInScope = <String>[];
      for (final tool in allTools) {
        if (!AgentToolScope.instance.hasRequirement(tool.name)) {
          missingInScope.add(tool.name);
        }
      }

      expect(
        missingInScope,
        isEmpty,
        reason: 'Tools in registry missing from AgentToolScope.requirements: $missingInScope',
      );
    });

    test('every key in AgentToolScope.requirements corresponds to an actually registered tool', () {
      final missingInRegistry = <String>[];
      for (final toolName in AgentToolScope.requirements.keys) {
        if (!AgentToolRegistry.instance.hasTool(toolName)) {
          missingInRegistry.add(toolName);
        }
      }

      expect(
        missingInRegistry,
        isEmpty,
        reason: 'Keys in AgentToolScope.requirements missing from AgentToolRegistry: $missingInRegistry',
      );
    });

    test('universal tools (verify_state, ask_user, remember_fact, recall_facts) are allowed for all personas', () {
      final personas = PersonaRegistry.instance.allPersonas;
      const universalTools = ['verify_state', 'ask_user', 'remember_fact', 'recall_facts'];

      for (final persona in personas) {
        final allowed = AgentToolScope.instance.allowedToolNames(persona.id);
        for (final uTool in universalTools) {
          expect(
            allowed.contains(uTool),
            isTrue,
            reason: 'Universal tool $uTool should be allowed for persona ${persona.id}',
          );
        }
      }
    });

    test('sleep assistant is restricted to sleep domain and does not receive sports tools', () {
      final sleepAllowed = AgentToolScope.instance.allowedToolNames('sleep');
      expect(sleepAllowed.contains('get_sleep_diagnostics'), isTrue);
      expect(sleepAllowed.contains('get_sports_history'), isFalse);
      expect(sleepAllowed.contains('log_sports_session'), isFalse);
    });
  });
}
