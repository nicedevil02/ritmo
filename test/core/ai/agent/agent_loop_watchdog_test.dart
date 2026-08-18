import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_tool_call_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A-10: shouldScanForToolCalls targeted trigger', () {
    test('returns false for ordinary text without tool tags', () {
      expect(AgentToolCallParser.shouldScanForToolCalls('سلام چطوری؟'), isFalse);
      expect(AgentToolCallParser.shouldScanForToolCalls('1 < 2 is a math inequality'), isFalse);
      expect(AgentToolCallParser.shouldScanForToolCalls('Here is a bracket [1] note'), isFalse);
      expect(AgentToolCallParser.shouldScanForToolCalls('`inline code`'), isFalse);
    });

    test('returns true when tool call markers are present', () {
      expect(AgentToolCallParser.shouldScanForToolCalls('سلام <tool_call>{"tool": "x"}'), isTrue);
      expect(AgentToolCallParser.shouldScanForToolCalls('<ritmo-tool name="x">'), isTrue);
      expect(AgentToolCallParser.shouldScanForToolCalls('<actions>[{"action": "y"}]'), isTrue);
      expect(AgentToolCallParser.shouldScanForToolCalls('<memory_ops>'), isTrue);
      expect(AgentToolCallParser.shouldScanForToolCalls('<function=get_weather>'), isTrue);
      expect(AgentToolCallParser.shouldScanForToolCalls('```tool\n{"name": "a"}\n```'), isTrue);
      expect(AgentToolCallParser.shouldScanForToolCalls('```json\n{"tool_call": "a"}\n```'), isTrue);
      expect(AgentToolCallParser.shouldScanForToolCalls('[TOOL_CALL]{"tool":"a"}[/TOOL_CALL]'), isTrue);
      expect(AgentToolCallParser.shouldScanForToolCalls('[TOOL]{"tool":"a"}[/TOOL]'), isTrue);
    });
  });
}
