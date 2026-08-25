import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';
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
    test(
      'every registered tool has a corresponding entry in AgentToolScope.requirements',
      () {
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
          reason:
              'Tools in registry missing from AgentToolScope.requirements: $missingInScope',
        );
      },
    );

    test(
      'every key in AgentToolScope.requirements corresponds to an actually registered tool',
      () {
        final missingInRegistry = <String>[];
        for (final toolName in AgentToolScope.requirements.keys) {
          if (!AgentToolRegistry.instance.hasTool(toolName)) {
            missingInRegistry.add(toolName);
          }
        }

        expect(
          missingInRegistry,
          isEmpty,
          reason:
              'Keys in AgentToolScope.requirements missing from AgentToolRegistry: $missingInRegistry',
        );
      },
    );

    test(
      'universal tools (verify_state, ask_user, remember_fact, recall_facts) are allowed for all personas',
      () {
        final personas = PersonaRegistry.instance.allPersonas;
        const universalTools = [
          'verify_state',
          'ask_user',
          'remember_fact',
          'recall_facts',
        ];

        for (final persona in personas) {
          final allowed = AgentToolScope.instance.allowedToolNames(persona.id);
          for (final uTool in universalTools) {
            expect(
              allowed.contains(uTool),
              isTrue,
              reason:
                  'Universal tool $uTool should be allowed for persona ${persona.id}',
            );
          }
        }
      },
    );

    test(
      'C-1: every mutating tool (policy != readOnly) must have a command requirement or be universal in AgentToolScope',
      () {
        final allTools = AgentToolRegistry.instance.allTools;
        for (final tool in allTools) {
          if (tool.policy != ToolPolicy.readOnly) {
            final req = AgentToolScope.requirements[tool.name];
            expect(
              req,
              isNotNull,
              reason: 'Tool ${tool.name} is missing from AgentToolScope.requirements',
            );
            expect(
              req!.commandId != null || req.isUniversal,
              isTrue,
              reason:
                  'Mutating tool "${tool.name}" (policy=${tool.policy}) must have a command requirement or be universal, but was readDomain=${req.readDomain}',
            );
          }
        }
        // Specific check for C-1:
        expect(
          AgentToolScope.requirements['create_worship_practice']?.commandId,
          equals('worship.create'),
        );
      },
    );

    test('C-7: kAiPersonaScopeEnforced controls fail-open vs fail-closed for unknown personas', () {
      kAiPersonaScopeEnforced = false;
      final failOpenTools = AgentToolScope.instance.allowedToolNames('unknown_persona_id');
      expect(failOpenTools.length, AgentToolRegistry.instance.allTools.length);

      kAiPersonaScopeEnforced = true;
      final failClosedTools = AgentToolScope.instance.allowedToolNames('unknown_persona_id');
      expect(failClosedTools, contains('verify_state'));
      expect(failClosedTools, contains('ask_user'));
      expect(failClosedTools, contains('remember_fact'));
      expect(failClosedTools, contains('recall_facts'));
      expect(failClosedTools, contains('undo_last_action'));
      expect(failClosedTools.contains('get_sleep_diagnostics'), isFalse);
      expect(failClosedTools.contains('create_new_routine'), isFalse);

      kAiPersonaScopeEnforced = false; // Reset
    });
  });
}


