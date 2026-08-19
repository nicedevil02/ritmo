import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';
import 'package:ritmo/core/ai/agent/ui/agent_stream_presenter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A-87: Post-Stream Suppression and Presentation Integrity', () {
    late AgentStreamPresenter presenter;

    setUp(() {
      presenter = AgentStreamPresenter();
    });

    test('AgentStreamPresenter does not wipe visibleText on AgentCompletedEvent', () {
      // 1. Turn start and final answer reset
      presenter.apply(const AgentTurnStartedEvent(turn: 1, maxTurns: 3));
      presenter.apply(const AgentDisplayResetEvent(
        turnKind: AgentTurnKind.finalAnswerTurn,
        turn: 1,
      ));

      expect(presenter.isSuppressed, isFalse);

      // 2. Stream tokens
      presenter.apply(const AgentTokenStreamEvent(
        delta: 'سلام ',
        accumulated: 'سلام ',
      ));
      presenter.apply(const AgentTokenStreamEvent(
        delta: 'عزیز',
        accumulated: 'سلام عزیز',
      ));

      expect(presenter.visibleText, equals('سلام عزیز'));

      // 3. Completion event
      presenter.apply(const AgentCompletedEvent(
        finalAnswer: 'سلام عزیز',
        rawAnswer: 'سلام عزیز',
        steps: [],
      ));

      expect(presenter.visibleText, equals('سلام عزیز'));
      expect(presenter.isWorking, isFalse);
    });

    test('Tool call turn suppresses text and clears visible buffer', () {
      presenter.apply(const AgentTurnStartedEvent(turn: 1, maxTurns: 3));
      presenter.apply(const AgentDisplayResetEvent(
        turnKind: AgentTurnKind.toolCallTurn,
        turn: 1,
      ));

      expect(presenter.isSuppressed, isTrue);

      // Subsequent token event while suppressed does not leak to visibleText
      presenter.apply(const AgentTokenStreamEvent(
        delta: '<tool_call>',
        accumulated: '<tool_call>',
      ));

      expect(presenter.visibleText, isEmpty);
    });
  });
}
