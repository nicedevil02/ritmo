import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_tool_call_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A-92: AgentToolCallParser.stripNoisePrefix Tests', () {
    test('strips ChatGPT said: prefixes cleanly', () {
      expect(
        AgentToolCallParser.stripNoisePrefix('ChatGPT said: سلام روز شما بخیر'),
        equals('سلام روز شما بخیر'),
      );
      expect(
        AgentToolCallParser.stripNoisePrefix(':ChatGPT said: سلام!'),
        equals('سلام!'),
      );
      expect(
        AgentToolCallParser.stripNoisePrefix('ChatGPT: سلام'),
        equals('سلام'),
      );
    });

    test('strips You said: and Assistant said: prefixes', () {
      expect(
        AgentToolCallParser.stripNoisePrefix('Assistant said: پاسخ شما آماده است.'),
        equals('پاسخ شما آماده است.'),
      );
      expect(
        AgentToolCallParser.stripNoisePrefix('• You said: پیام من'),
        equals('پیام من'),
      );
    });

    test('preserves normal Persian text without prefixes', () {
      const normalText = 'سلام! امروز برای ورزش چه برنامه‌ای داری؟';
      expect(
        AgentToolCallParser.stripNoisePrefix(normalText),
        equals(normalText),
      );
    });

    test('extractFirstJsonObject extracts json object cleanly from surrounded text', () {
      const sample = 'متن قبل {"key": "value", "nested": {"a": 1}} متن بعد';
      final extracted = AgentToolCallParser.extractFirstJsonObject(sample);
      expect(extracted, equals('{"key": "value", "nested": {"a": 1}}'));
    });
  });
}
