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

    test('B1: admit -> unadmit restores toolCalls capacity', () {
      final budget = AgentBudget(maxToolCalls: 2);
      final admission1 = budget.admit('tool_a', {'k': 'v'});
      expect(admission1.allowed, isTrue);
      expect(budget.toolCallsUsed, equals(1));

      budget.unadmit('tool_a', {'k': 'v'});
      expect(budget.toolCallsUsed, equals(0));
      expect(budget.toolCallsLeft, equals(2));
    });

    test('B2: admit -> unadmit -> wasRejected is true and repeat admission with same args is rejected', () {
      final budget = AgentBudget(maxToolCalls: 2);
      budget.admit('tool_a', {'k': 'v'});
      budget.unadmit('tool_a', {'k': 'v'});

      expect(budget.wasRejected('tool_a', {'k': 'v'}), isTrue);
      final repeatAdmission = budget.admit('tool_a', {'k': 'v'});
      expect(repeatAdmission.allowed, isFalse, reason: 'Duplicate rejected call signature must not be admitted');
    });

    test('B3: admit -> unadmit -> admission with different args is accepted', () {
      final budget = AgentBudget(maxToolCalls: 2);
      budget.admit('tool_a', {'k': 'v1'});
      budget.unadmit('tool_a', {'k': 'v1'});

      expect(budget.wasRejected('tool_a', {'k': 'v2'}), isFalse);
      final newAdmission = budget.admit('tool_a', {'k': 'v2'});
      expect(newAdmission.allowed, isTrue);
      expect(budget.toolCallsUsed, equals(1));
    });

    test('B4: nested pauseClock (2 pause, 2 resume) pauses wallClock and resumes only on final resume', () async {
      final budget = AgentBudget(wallClock: const Duration(milliseconds: 60));
      budget.pauseClock();
      budget.pauseClock(); // Depth 2
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(budget.isTimedOut, isFalse);

      budget.resumeClock(); // Depth 1 (still paused)
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(budget.isTimedOut, isFalse);

      budget.resumeClock(); // Depth 0 (resumed)
      expect(budget.isTimedOut, isFalse);
    });

    test('B5: clearReadSignatures only clears read signatures, retaining write and rejected signatures', () {
      final budget = AgentBudget(maxToolCalls: 5);
      budget.admit('verify_state', {'check': 'routine'}, isReadOnly: true);
      budget.admit('create_new_routine', {'title': 'Morning Run'}, isReadOnly: false);
      budget.admit('delete_routine', {'id': '123'}, isReadOnly: false);
      budget.unadmit('delete_routine', {'id': '123'});

      // Clear read signatures only
      budget.clearReadSignatures();

      // Read tool is allowed again
      expect(budget.admit('verify_state', {'check': 'routine'}, isReadOnly: true).allowed, isTrue);

      // Mutating tool signature is still remembered
      expect(budget.admit('create_new_routine', {'title': 'Morning Run'}, isReadOnly: false).allowed, isFalse);

      // Rejected signature is still remembered
      expect(budget.wasRejected('delete_routine', {'id': '123'}), isTrue);
      expect(budget.admit('delete_routine', {'id': '123'}, isReadOnly: false).allowed, isFalse);
    });
  });
}

