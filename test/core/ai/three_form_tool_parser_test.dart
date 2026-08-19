import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_tool_call_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WEB-28: Three-Form Tool Call Parsing', () {
    test('Form 1: Markdown code block parsing with action and parameters (A-78)', () {
      const input = '''
من هدف شما را ثبت می‌کنم:
```tool
{
  "action": "create_goal",
  "parameters": {
    "title": "ورزش روزانه",
    "target": 30
  }
}
```
لطفاً بررسی کنید.
''';

      final scan = AgentToolCallParser.scan(input, knownToolNames: {'create_goal'});

      expect(scan.hasCalls, isTrue);
      expect(scan.calls.length, equals(1));
      expect(scan.calls.first.toolName, equals('create_goal'));
      expect(scan.calls.first.parameters['title'], equals('ورزش روزانه'));
      expect(scan.calls.first.parameters['target'], equals(30));
      expect(scan.cleanText.contains('```tool'), isFalse);
    });

    test('Form 2: Structured XML/Bracket tags (<tool_call>, <tool>, [TOOL_CALL])', () {
      const xmlInput = '<tool_call>{"name": "schedule_event", "arguments": {"time": "14:00"}}</tool_call>';
      final scan1 = AgentToolCallParser.scan(xmlInput);
      expect(scan1.hasCalls, isTrue);
      expect(scan1.calls.first.toolName, equals('schedule_event'));
      expect(scan1.calls.first.parameters['time'], equals('14:00'));

      const toolTagInput = '<tool>{"tool": "add_note", "args": {"text": "خرید کتاب"}}</tool>';
      final scan2 = AgentToolCallParser.scan(toolTagInput);
      expect(scan2.hasCalls, isTrue);
      expect(scan2.calls.first.toolName, equals('add_note'));
      expect(scan2.calls.first.parameters['text'], equals('خرید کتاب'));

      const bracketInput = '[TOOL_CALL]{"tool_name": "log_water", "params": {"amount": 250}}[/TOOL_CALL]';
      final scan3 = AgentToolCallParser.scan(bracketInput);
      expect(scan3.hasCalls, isTrue);
      expect(scan3.calls.first.toolName, equals('log_water'));
      expect(scan3.calls.first.parameters['amount'], equals(250));
    });

    test('Form 3: Plain / bare JSON response with equivalent keys (A-79)', () {
      const bareJsonInput = '{"tool": "calculate_stats", "data": {"days": 7}}';
      final scan = AgentToolCallParser.scan(bareJsonInput, knownToolNames: {'calculate_stats'});

      expect(scan.hasCalls, isTrue);
      expect(scan.calls.first.toolName, equals('calculate_stats'));
      expect(scan.calls.first.parameters['days'], equals(7));
      expect(scan.cleanText, isEmpty);
    });

    test('Key alias normalization for function and input keys', () {
      const input = '<tool_call>{"function": "search_database", "input": {"query": "flutter"}}</tool_call>';
      final scan = AgentToolCallParser.scan(input);

      expect(scan.hasCalls, isTrue);
      expect(scan.calls.first.toolName, equals('search_database'));
      expect(scan.calls.first.parameters['query'], equals('flutter'));
    });
  });
}
