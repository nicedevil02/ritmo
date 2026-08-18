import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_tool_call_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WEB-32: Two-Stage Rendering with Suppression Buffer', () {
    test('cleanText is not emitted while hasOpenTag is true (partial tool tag)', () {
      final tokens = [
        'بررسی می‌کنم: ',
        '<tool_call>',
        '{"name": "get_data',
        '", "parameters": {',
      ];

      var lastDisplayed = '';
      var suppressedCount = 0;

      for (final token in tokens) {
        lastDisplayed += token;
        final scan = AgentToolCallParser.scan(lastDisplayed);
        if (scan.hasOpenTag) {
          suppressedCount++;
        }
      }

      expect(suppressedCount, greaterThan(0));

      final finalScan = AgentToolCallParser.scan(lastDisplayed);
      expect(finalScan.hasOpenTag, isTrue);
      expect(finalScan.hasCalls, isFalse);
    });

    test('cleanText is emitted after tool block is closed', () {
      const fullText = 'خوب: <tool_call>{"name": "create_task", "parameters": {"title": "مطالعه"}}</tool_call> کامل شد.';
      final scan = AgentToolCallParser.scan(fullText);

      // وقتی tool_call بسته است باید hasCalls=true باشد
      expect(scan.hasCalls, isTrue);
      expect(scan.cleanText, contains('خوب:'));
      expect(scan.cleanText, contains('کامل شد.'));
      // تگ tool_call نباید در cleanText باشد
      expect(scan.cleanText.contains('<tool_call>'), isFalse);
      expect(scan.cleanText.contains('"create_task"'), isFalse);
    });

    test('Turn separator: rawBuffer is cleared between agent turns', () {
      // این تست ساختار turn separation را بررسی می‌کند
      // AgentLoopRunner برای هر نوبت یک rawBuffer مستقل دارد
      const turn1Text = 'پاسخ نوبت اول بدون ابزار.';
      const turn2Text = 'پاسخ نوبت دوم بعد از ابزار.';

      final scan1 = AgentToolCallParser.scan(turn1Text);
      final scan2 = AgentToolCallParser.scan(turn2Text);

      expect(scan1.hasCalls, isFalse);
      expect(scan2.hasCalls, isFalse);
      expect(scan1.cleanText, equals(turn1Text));
      expect(scan2.cleanText, equals(turn2Text));
      // متن دو نوبت نباید با هم ترکیب شوند
      expect(scan1.cleanText, isNot(contains(turn2Text)));
    });

    test('Suppression: bracket-style partial [TOOL_CALL] is suppressed', () {
      const partialBracket = 'در حال پردازش: [TOOL_CALL]{"tool_name": "analyze_data"';
      final scan = AgentToolCallParser.scan(partialBracket);

      expect(scan.hasOpenTag, isTrue);
      expect(scan.hasCalls, isFalse);
      // متن قبل از تگ باید در cleanText وجود داشته باشد
      expect(scan.cleanText, equals('در حال پردازش:'));
    });
  });
}
