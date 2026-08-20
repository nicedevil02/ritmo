import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';
import 'package:ritmo/core/ai/agent/ui/agent_stream_presenter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A-88: Consecutive Agent Turns Lifecycle and Presentation', () {
    late AgentStreamPresenter presenter;

    setUp(() {
      presenter = AgentStreamPresenter();
    });

    test(
      'multi-turn sequence: Turn 1 tool call -> Turn 2 final answer flows without text loss',
      () {
        // --- TURN 1 (Tool Call) ---
        presenter.apply(const AgentTurnStartedEvent(turn: 1, maxTurns: 3));
        presenter.apply(
          const AgentDisplayResetEvent(
            turnKind: AgentTurnKind.finalAnswerTurn,
            turn: 1,
          ),
        );

        // Emitting tool call markup
        presenter.apply(
          const AgentTokenStreamEvent(
            delta: '<tool_call>{"tool": "get_data"}</tool_call>',
            accumulated: '<tool_call>{"tool": "get_data"}</tool_call>',
          ),
        );

        // End of Turn 1 with tool call detected -> reset toolCallTurn
        presenter.apply(
          const AgentDisplayResetEvent(
            turnKind: AgentTurnKind.toolCallTurn,
            turn: 1,
          ),
        );

        expect(presenter.isSuppressed, isTrue);
        expect(presenter.visibleText, isEmpty);

        // Step completed event
        presenter.apply(
          AgentStepCompletedEvent(
            AgentStep(
              id: 'step_1',
              toolName: 'get_data',
              titleFa: 'دریافت اطلاعات',
              status: AgentStepStatus.success,
              startTime: DateTime.now(),
            ),
          ),
        );

        // --- TURN 2 (Final Answer) ---
        presenter.apply(const AgentTurnStartedEvent(turn: 2, maxTurns: 3));
        // T-12 / A-77: finalAnswerTurn reset event emitted at start of Turn 2 lifts suppression
        presenter.apply(
          const AgentDisplayResetEvent(
            turnKind: AgentTurnKind.finalAnswerTurn,
            turn: 2,
          ),
        );

        expect(presenter.isSuppressed, isFalse);

        // Streaming tokens in Turn 2
        presenter.apply(
          const AgentTokenStreamEvent(
            delta: 'بر اساس بررسی‌های انجام شده، ',
            accumulated: 'بر اساس بررسی‌های انجام شده، ',
          ),
        );
        presenter.apply(
          const AgentTokenStreamEvent(
            delta: 'شما امروز وضعیت عالی داشتید.',
            accumulated:
                'بر اساس بررسی‌های انجام شده، شما امروز وضعیت عالی داشتید.',
          ),
        );

        expect(
          presenter.visibleText,
          equals('بر اساس بررسی‌های انجام شده، شما امروز وضعیت عالی داشتید.'),
        );

        // Final completion
        presenter.apply(
          const AgentCompletedEvent(
            finalAnswer:
                'بر اساس بررسی‌های انجام شده، شما امروز وضعیت عالی داشتید.',
            rawAnswer:
                'بر اساس بررسی‌های انجام شده، شما امروز وضعیت عالی داشتید.',
            steps: [],
          ),
        );

        // Assert text was NOT wiped after completion
        expect(
          presenter.visibleText,
          equals('بر اساس بررسی‌های انجام شده، شما امروز وضعیت عالی داشتید.'),
        );
        expect(presenter.isWorking, isFalse);
      },
    );
  });
}
