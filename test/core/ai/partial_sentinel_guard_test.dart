import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_tool_call_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WEB-29: Partial Sentinel Guard & Streaming Suppression', () {
    test('Unfinished <tool_call> tag is suppressed from cleanText and sets hasOpenTag=true', () {
      const partialStream = 'سلام دوست عزیز. <tool_call>{"name": "create_goal", "arg';
      final scan = AgentToolCallParser.scan(partialStream);

      expect(scan.hasOpenTag, isTrue);
      expect(scan.hasCalls, isFalse);
      expect(scan.cleanText, equals('سلام دوست عزیز.'));
    });

    test('Unfinished [TOOL_CALL] bracket tag is suppressed and sets hasOpenTag=true', () {
      const partialBracket = 'در حال بررسی: [TOOL_CALL]{"tool_name": "fetch_weather"';
      final scan = AgentToolCallParser.scan(partialBracket);

      expect(scan.hasOpenTag, isTrue);
      expect(scan.hasCalls, isFalse);
      expect(scan.cleanText, equals('در حال بررسی:'));
    });

    test('Unfinished markdown tool code block is suppressed and sets hasOpenTag=true (A-78)', () {
      const partialCodeBlock = 'ثبت برنامه:\n```tool\n{"action": "add_routine", "parameters": {';
      final scan = AgentToolCallParser.scan(partialCodeBlock, knownToolNames: {'add_routine'});

      expect(scan.hasOpenTag, isTrue);
      expect(scan.hasCalls, isFalse);
      expect(scan.cleanText, equals('ثبت برنامه:'));
    });

    test('Completing the tag closes hasOpenTag and yields parsed tool calls (A-78)', () {
      const fullText = 'ثبت برنامه:\n```tool\n{"action": "add_routine", "parameters": {"name": "مطالعه"}}\n```\nانجام شد.';
      final scan = AgentToolCallParser.scan(fullText, knownToolNames: {'add_routine'});

      expect(scan.hasOpenTag, isFalse);
      expect(scan.hasCalls, isTrue);
      expect(scan.calls.first.toolName, equals('add_routine'));
      expect(scan.calls.first.parameters['name'], equals('مطالعه'));
      expect(scan.cleanText, contains('ثبت برنامه:'));
      expect(scan.cleanText, contains('انجام شد.'));
      expect(scan.cleanText.contains('```tool'), isFalse);
    });
  });
}
