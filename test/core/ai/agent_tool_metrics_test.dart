import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/agent_tool_registry.dart';

class _DummyEchoTool extends AgentTool {
  const _DummyEchoTool()
    : super(
        name: 'dummy_echo',
        categoryFa: 'تست',
        titleFa: 'ابزار آزمایشی',
        descriptionFa: 'ابزار آزمایشی برای بررسی تلمتری',
      );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    if (args['fail'] == true) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'خطای آزمایشی',
      );
    }
    return AgentToolResult.success(
      toolName: name,
      data: args,
      summaryFa: 'موفق',
    );
  }
}

void main() {
  group('AgentToolMetrics Telemetry Tests (T39)', () {
    setUp(() {
      AgentToolRegistry.instance.resetMetrics();
      AgentToolRegistry.instance.register(const _DummyEchoTool());
    });

    test('records call count, success count and duration correctly', () async {
      final res1 = await AgentToolRegistry.instance.executeTool('dummy_echo', {
        'key': 'val',
      });
      expect(res1.isSuccess, isTrue);

      final metricAfter1 = AgentToolRegistry.instance.getMetrics('dummy_echo');
      expect(metricAfter1.callCount, 1);
      expect(metricAfter1.successCount, 1);
      expect(metricAfter1.failureCount, 0);

      final res2 = await AgentToolRegistry.instance.executeTool('dummy_echo', {
        'fail': true,
      });
      expect(res2.isSuccess, isFalse);

      final metricAfter2 = AgentToolRegistry.instance.getMetrics('dummy_echo');
      expect(metricAfter2.callCount, 2);
      expect(metricAfter2.successCount, 1);
      expect(metricAfter2.failureCount, 1);
      expect(metricAfter2.successRate, 0.5);
    });
  });
}
