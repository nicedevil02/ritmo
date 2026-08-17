import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_tool_call_parser.dart';

void main() {
  group('AgentToolCallParser cleanForDisplay Tests (T10)', () {
    test('preserves prefix and suffix text around closed tool_call tags', () {
      const raw = 'سلام! <tool_call>{"name": "get_routines", "parameters": {}}</tool_call> این هم نتیجه.';
      final cleaned = AgentToolCallParser.cleanForDisplay(raw);
      expect(cleaned, 'سلام! این هم نتیجه.');
    });

    test('preserves suffix text when tool_call is at the beginning', () {
      const raw = '<tool_call>{"name": "get_routines", "parameters": {}}</tool_call> این هم نتیجه.';
      final cleaned = AgentToolCallParser.cleanForDisplay(raw);
      expect(cleaned, 'این هم نتیجه.');
    });

    test('preserves prefix text when tool_call is at the end', () {
      const raw = 'سلام! <tool_call>{"name": "get_routines", "parameters": {}}</tool_call>';
      final cleaned = AgentToolCallParser.cleanForDisplay(raw);
      expect(cleaned, 'سلام!');
    });

    test('handles unclosed dangling tool_call tag gracefully by keeping prefix', () {
      const raw = 'سلام! در حال خواندن داده‌ها... <tool_call>{"name": "get_routines", "parameters":';
      final cleaned = AgentToolCallParser.cleanForDisplay(raw);
      expect(cleaned, 'سلام! در حال خواندن داده‌ها...');
    });

    test('cleans actions and memory tags while preserving message text', () {
      const raw = 'برنامه شما تنظیم شد. <actions>[{"type":"createRoutine","payload":{}}]</actions> <memory_ops>[]</memory_ops> روز خوبی داشته باشید!';
      final cleaned = AgentToolCallParser.cleanForDisplay(raw);
      expect(cleaned, 'برنامه شما تنظیم شد. روز خوبی داشته باشید!');
    });
  });
}
