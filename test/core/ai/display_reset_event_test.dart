import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WEB-33: AgentDisplayResetEvent و AgentTurnKind', () {
    test('AgentTurnKind.toolCallTurn exists and is distinct', () {
      expect(AgentTurnKind.toolCallTurn, isNotNull);
      expect(AgentTurnKind.finalAnswerTurn, isNotNull);
      expect(AgentTurnKind.toolCallTurn, isNot(AgentTurnKind.finalAnswerTurn));
    });

    test('AgentDisplayResetEvent is an AgentEvent', () {
      const event = AgentDisplayResetEvent(
        turnKind: AgentTurnKind.toolCallTurn,
        turn: 1,
      );
      expect(event, isA<AgentEvent>());
      expect(event.turnKind, AgentTurnKind.toolCallTurn);
      expect(event.turn, 1);
    });

    test('AgentDisplayResetEvent for finalAnswerTurn carries correct kind', () {
      const event = AgentDisplayResetEvent(
        turnKind: AgentTurnKind.finalAnswerTurn,
        turn: 2,
      );
      expect(event.turnKind, AgentTurnKind.finalAnswerTurn);
      expect(event.turn, 2);
    });

    test('toolCallTurn reset signals buffer should be discarded', () {
      // مصرف‌کننده باید وقتی turnKind == toolCallTurn بافر نمایش را دور بریزد
      const event = AgentDisplayResetEvent(
        turnKind: AgentTurnKind.toolCallTurn,
        turn: 1,
      );
      final shouldDiscard = event.turnKind == AgentTurnKind.toolCallTurn;
      expect(shouldDiscard, isTrue);
    });

    test('finalAnswerTurn reset signals buffer should be kept', () {
      // مصرف‌کننده باید وقتی turnKind == finalAnswerTurn بافر را نگه دارد
      const event = AgentDisplayResetEvent(
        turnKind: AgentTurnKind.finalAnswerTurn,
        turn: 3,
      );
      final shouldDiscard = event.turnKind == AgentTurnKind.toolCallTurn;
      expect(shouldDiscard, isFalse);
    });
  });
}
