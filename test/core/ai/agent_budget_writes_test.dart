import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_budget.dart';
import 'package:ritmo/core/ai/agent/agent_policy_gate.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';

class _DummyWriteTool extends AgentTool {
  const _DummyWriteTool()
    : super(
        name: 'dummy_write',
        categoryFa: 'تست',
        titleFa: 'ابزار تست نوشتن',
        descriptionFa: 'ابزار آزمایشی تغییردهنده',
        policy: ToolPolicy.actionDirect,
      );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    return AgentToolResult.success(
      toolName: name,
      data: args,
      summaryFa: 'موفق',
    );
  }
}

void main() {
  group('Configurable Write Limits Tests (T43)', () {
    const tool = _DummyWriteTool();

    test('respects custom maxWrites passed to evaluate', () {
      // Default limit is 3, but with custom maxWrites=1:
      final res1 = AgentPolicyGate.instance.evaluate(
        tool: tool,
        args: {'field': 'val'},
        writesUsedThisRun: 0,
        maxWrites: 1,
      );
      expect(res1.isAllowed, isTrue);

      final res2 = AgentPolicyGate.instance.evaluate(
        tool: tool,
        args: {'field': 'val'},
        writesUsedThisRun: 1,
        maxWrites: 1,
      );
      expect(res2.isDenied, isTrue);
      expect(res2.reasonFa, contains('حداکثر 1 تغییر مجاز است'));
    });

    test('AgentBudget initializes with custom maxWrites', () {
      final customBudget = AgentBudget(maxWrites: 5);
      expect(customBudget.maxWrites, 5);
    });

    test('C-5: pauseClock and resumeClock with reentrancy depth pause wallClock', () async {
      final budget = AgentBudget(wallClock: const Duration(milliseconds: 50));
      budget.pauseClock();
      budget.pauseClock(); // Depth 2
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(budget.isTimedOut, isFalse);

      budget.resumeClock(); // Depth 1, still paused
      expect(budget.isTimedOut, isFalse);

      budget.resumeClock(); // Depth 0, resumed
      expect(budget.isTimedOut, isFalse);
    });

    test('C-6: unadmit refunds toolCalls and removes signature', () {
      final budget = AgentBudget(maxToolCalls: 2);
      final admission1 = budget.admit('tool_a', {'k': 'v'});
      expect(admission1.allowed, isTrue);
      expect(budget.toolCallsUsed, 1);

      // Repeat admission should be denied
      final admission2 = budget.admit('tool_a', {'k': 'v'});
      expect(admission2.allowed, isFalse);

      // Unadmit
      budget.unadmit('tool_a', {'k': 'v'});
      expect(budget.toolCallsUsed, 0);

      // Now admission should be allowed again
      final admission3 = budget.admit('tool_a', {'k': 'v'});
      expect(admission3.allowed, isTrue);
      expect(budget.toolCallsUsed, 1);
    });

    test('C-6: clearReadSignatures allows re-inspection of read-only tools', () {
      final budget = AgentBudget();
      budget.admit('verify_state', {'check': 'routine_in_day'}, isReadOnly: true);
      expect(budget.admit('verify_state', {'check': 'routine_in_day'}, isReadOnly: true).allowed, isFalse);

      budget.clearReadSignatures();
      expect(budget.admit('verify_state', {'check': 'routine_in_day'}, isReadOnly: true).allowed, isTrue);
    });
  });
}

