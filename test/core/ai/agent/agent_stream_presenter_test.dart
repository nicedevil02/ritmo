import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';
import 'package:ritmo/core/ai/agent/agent_policy_gate.dart';
import 'package:ritmo/core/ai/agent/ui/agent_stream_presenter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A-21: AgentStreamPresenter State Machine Tests', () {
    late AgentStreamPresenter presenter;

    setUp(() {
      presenter = AgentStreamPresenter();
    });

    test('initial state is clean and idle', () {
      expect(presenter.visibleText, isEmpty);
      expect(presenter.isWorking, isFalse);
      expect(presenter.isSuppressed, isFalse);
      expect(presenter.pendingQuestion, isNull);
      expect(presenter.pendingConfirmation, isNull);
      expect(presenter.errorFa, isNull);
      expect(presenter.steps, isEmpty);
    });

    test('AgentTokenStreamEvent updates visibleText when not suppressed', () {
      presenter.apply(const AgentTokenStreamEvent(delta: 'سلام', accumulated: 'سلام کاربر'));
      expect(presenter.visibleText, equals('سلام کاربر'));
    });

    test('AgentDisplayResetEvent(toolCallTurn) suppresses text emission and clears visibleText', () {
      presenter.apply(const AgentTokenStreamEvent(delta: 'tool', accumulated: '<tool_call>...'));
      expect(presenter.visibleText, equals('<tool_call>...'));

      presenter.apply(const AgentDisplayResetEvent(turnKind: AgentTurnKind.toolCallTurn, turn: 1));
      expect(presenter.isSuppressed, isTrue);
      expect(presenter.visibleText, isEmpty);
      expect(presenter.isWorking, isTrue);

      // Token stream emitted while suppressed does NOT leak to visibleText
      presenter.apply(const AgentTokenStreamEvent(delta: 'internal', accumulated: 'hidden json'));
      expect(presenter.visibleText, isEmpty);
    });

    test('AgentDisplayResetEvent(finalAnswerTurn) lifts suppression', () {
      presenter.apply(const AgentDisplayResetEvent(turnKind: AgentTurnKind.toolCallTurn, turn: 1));
      expect(presenter.isSuppressed, isTrue);

      presenter.apply(const AgentDisplayResetEvent(turnKind: AgentTurnKind.finalAnswerTurn, turn: 2));
      expect(presenter.isSuppressed, isFalse);

      presenter.apply(const AgentTokenStreamEvent(delta: 'پاسخ', accumulated: 'پاسخ نهایی'));
      expect(presenter.visibleText, equals('پاسخ نهایی'));
    });

    test('AgentCompletedEvent sets finalAnswer, clears pending requests and stops working', () {
      presenter.apply(const AgentAwaitingConfirmationEvent(AgentConfirmationRequest(
        id: 'c1',
        toolName: 'remember',
        titleFa: 'ثبت',
        previewFa: 'پیش‌نمایش',
        parameters: {},
      )));
      expect(presenter.pendingConfirmation, isNotNull);

      presenter.apply(const AgentCompletedEvent(
        finalAnswer: 'پاسخ کامل',
        steps: [],
      ));

      expect(presenter.visibleText, equals('پاسخ کامل'));
      expect(presenter.isWorking, isFalse);
      expect(presenter.pendingConfirmation, isNull);
    });

    test('reset clears all state variables', () {
      presenter.apply(const AgentStatusChangedEvent(statusTextFa: 'در حال کار', isWorking: true));
      presenter.apply(const AgentTokenStreamEvent(delta: 'a', accumulated: 'abc'));
      expect(presenter.visibleText, equals('abc'));
      expect(presenter.isWorking, isTrue);

      presenter.reset();
      expect(presenter.visibleText, isEmpty);
      expect(presenter.isWorking, isFalse);
      expect(presenter.statusTextFa, isEmpty);
    });
  });
}
