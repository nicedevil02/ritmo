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
  });
}
