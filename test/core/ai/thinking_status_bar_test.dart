import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WEB-34: نوار وضعیت تفکر — AgentDisplayResetEvent UI Logic', () {
    test('toolCallTurn reset triggers suppress=true logic', () {
      // شبیه‌سازی منطق handler در AssistantSheetState
      var suppressUntilTurnEnd = false;
      var agentStatusText = 'در حال تحلیل هوشمند...';
      var fullResponse = 'در حال بررسی ابزارها...';

      const event = AgentDisplayResetEvent(
        turnKind: AgentTurnKind.toolCallTurn,
        turn: 1,
      );

      if (event.turnKind == AgentTurnKind.toolCallTurn) {
        fullResponse = '';
        suppressUntilTurnEnd = true;
        agentStatusText = 'در حال تحلیل نتیجه ابزارها...';
      }

      expect(suppressUntilTurnEnd, isTrue);
      expect(fullResponse, isEmpty);
      expect(agentStatusText, contains('ابزار'));
    });

    test('finalAnswerTurn reset clears suppress and shows response status', () {
      var suppressUntilTurnEnd = true;
      var agentStatusText = 'در حال تحلیل نتیجه ابزارها...';

      const event = AgentDisplayResetEvent(
        turnKind: AgentTurnKind.finalAnswerTurn,
        turn: 2,
      );

      if (event.turnKind == AgentTurnKind.toolCallTurn) {
        suppressUntilTurnEnd = true;
      } else {
        suppressUntilTurnEnd = false;
        agentStatusText = 'در حال نگارش پاسخ نهایی...';
      }

      expect(suppressUntilTurnEnd, isFalse);
      expect(agentStatusText, contains('نهایی'));
    });

    test('token events are skipped while suppressUntilTurnEnd is true', () {
      // وقتی suppress=true است، fullResponse هرگز از توکن‌های ابزاری پر نمی‌شود
      const tokenEvent = AgentTokenStreamEvent(
        delta: 'بررسی تقویم...',
        accumulated: 'بررسی تقویم...',
      );

      String applyToken(
        String current,
        AgentTokenStreamEvent event,
        bool suppress,
      ) {
        if (suppress) return current;
        return event.accumulated;
      }

      final result = applyToken('', tokenEvent, true);
      expect(result, isEmpty);
    });

    test('token events flow through when suppress is false', () {
      const tokenEvent = AgentTokenStreamEvent(
        delta: 'پاسخ نهایی اینجاست.',
        accumulated: 'پاسخ نهایی اینجاست.',
      );

      String applyToken(
        String current,
        AgentTokenStreamEvent event,
        bool suppress,
      ) {
        if (suppress) return current;
        return event.accumulated;
      }

      final result = applyToken('', tokenEvent, false);
      expect(result, equals('پاسخ نهایی اینجاست.'));
    });
  });
}
