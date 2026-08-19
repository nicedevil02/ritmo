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

  group('AgentToolCallParser Multi-Format & XML Fallback Tests (T23)', () {
    test('parses standard JSON in tool_call tag', () {
      const raw = '<tool_call>{"tool": "get_routines_overview", "parameters": {"days": 7}}</tool_call>';
      final scan = AgentToolCallParser.scan(raw);
      expect(scan.hasCalls, isTrue);
      expect(scan.calls.length, 1);
      expect(scan.calls.first.toolName, 'get_routines_overview');
      expect(scan.calls.first.parameters['days'], 7);
    });

    test('parses XML-style elements inside tool_call tag', () {
      const raw = '<tool_call><name>get_sports_history</name><days>14</days></tool_call>';
      final scan = AgentToolCallParser.scan(raw);
      expect(scan.hasCalls, isTrue);
      expect(scan.calls.length, 1);
      expect(scan.calls.first.toolName, 'get_sports_history');
      expect(scan.calls.first.parameters['days'], 14);
    });

    test('parses function tag format <function=name>...', () {
      const raw = '<function=get_study_progress_summary>{"subject": "Math"}</function>';
      final scan = AgentToolCallParser.scan(raw);
      expect(scan.hasCalls, isTrue);
      expect(scan.calls.length, 1);
      expect(scan.calls.first.toolName, 'get_study_progress_summary');
      expect(scan.calls.first.parameters['subject'], 'Math');
    });

    test('parses markdown code block with tool JSON (A-78)', () {
      const raw = '```tool\n{"tool": "get_worship_practices", "parameters": {}}\n```';
      final scan = AgentToolCallParser.scan(raw, knownToolNames: {'get_worship_practices'});
      expect(scan.hasCalls, isTrue);
      expect(scan.calls.length, 1);
      expect(scan.calls.first.toolName, 'get_worship_practices');
    });

    test('parses bare JSON tool call with knownToolNames (A-79)', () {
      const raw = '{"tool": "get_sleep_diagnostics", "parameters": {"days": 30}}';
      final scan = AgentToolCallParser.scan(raw, knownToolNames: {'get_sleep_diagnostics'});
      expect(scan.hasCalls, isTrue);
      expect(scan.calls.length, 1);
      expect(scan.calls.first.toolName, 'get_sleep_diagnostics');
      expect(scan.calls.first.parameters['days'], 30);
    });

    test('ignores bare JSON when tool is not in knownToolNames (A-79)', () {
      const raw = '{"tool": "unknown_tool", "parameters": {}}';
      final scan = AgentToolCallParser.scan(raw, knownToolNames: {'get_sleep_diagnostics'});
      expect(scan.hasCalls, isFalse);
    });

    test('parses multiple tool calls in a single response', () {
      const raw = '''
<tool_call>{"tool": "get_routines_overview", "parameters": {"days": 7}}</tool_call>
<tool_call>{"tool": "get_sports_history", "parameters": {"days": 14}}</tool_call>
''';
      final scan = AgentToolCallParser.scan(raw);
      expect(scan.hasCalls, isTrue);
      expect(scan.calls.length, 2);
      expect(scan.calls[0].toolName, 'get_routines_overview');
      expect(scan.calls[1].toolName, 'get_sports_history');
    });

    test('handles Persian unicode characters inside tool parameters correctly', () {
      const raw = '<tool_call>{"tool": "create_routine", "parameters": {"title": "ورزش صبحگاهی", "category": "ورزش"}}</tool_call>';
      final scan = AgentToolCallParser.scan(raw);
      expect(scan.hasCalls, isTrue);
      expect(scan.calls.first.parameters['title'], 'ورزش صبحگاهی');
      expect(scan.calls.first.parameters['category'], 'ورزش');
    });

    test('handles corrupted JSON inside tool_call tag gracefully', () {
      const raw = '<tool_call>{tool: broken, "parameters": </tool_call>';
      final scan = AgentToolCallParser.scan(raw);
      // Corrupt JSON without name/tool produces no valid calls
      expect(scan.calls, isEmpty);
    });

    test('stableArgs produces deterministic string independent of key insertion order', () {
      final args1 = {'b': '2', 'a': '1', 'c': '3'};
      final args2 = {'a': '1', 'c': '3', 'b': '2'};
      expect(AgentToolCallParser.stableArgs(args1), equals(AgentToolCallParser.stableArgs(args2)));
    });
  });
}
