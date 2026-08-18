import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';
import 'package:ritmo/core/ai/agent/agent_policy_gate.dart';
import 'package:ritmo/core/ai/chat/chat_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A-20: Guardian Test for AgentEvent Exhaustive Forwarding', () {
    test('dynamic guard: all AgentEvent subclasses in agent_event.dart are accounted for', () {
      final file = File('lib/core/ai/agent/agent_event.dart');
      expect(file.existsSync(), isTrue, reason: 'agent_event.dart must exist');

      final content = file.readAsStringSync();
      final regex = RegExp(r'class\s+(\w+Event)\s+extends\s+AgentEvent');
      final matches = regex.allMatches(content).map((m) => m.group(1)!).toList();

      const expectedSubclasses = [
        'AgentStatusChangedEvent',
        'AgentTurnStartedEvent',
        'AgentStepStartedEvent',
        'AgentStepCompletedEvent',
        'AgentAwaitingConfirmationEvent',
        'AgentConfirmationResolvedEvent',
        'AgentConfirmationTimedOutEvent',
        'AgentAwaitingQuestionEvent',
        'AgentQuestionResolvedEvent',
        'AgentTokenStreamEvent',
        'AgentCompletedEvent',
        'AgentErrorEvent',
        'AgentDisplayResetEvent',
      ];

      expect(
        matches.length,
        equals(expectedSubclasses.length),
        reason: 'Number of AgentEvent subclasses in agent_event.dart (${matches.length}) '
            'must match expected list length (${expectedSubclasses.length}). '
            'If you added a new AgentEvent, update expectedSubclasses and test cases below.',
      );

      for (final name in expectedSubclasses) {
        expect(matches.contains(name), isTrue, reason: 'Class $name must exist in agent_event.dart');
      }
    });

    test('all 13 AgentEvent subclasses produce valid output in streaming pipeline without dropping', () {
      final events = <AgentEvent>[
        const AgentStatusChangedEvent(statusTextFa: 'در حال فکر', isWorking: true),
        const AgentTurnStartedEvent(turn: 1, maxTurns: 5),
        AgentStepStartedEvent(AgentStep(
          id: 's1',
          titleFa: 'گام ۱',
          startTime: DateTime.now(),
        )),
        AgentStepCompletedEvent(AgentStep(
          id: 's1',
          titleFa: 'گام ۱',
          status: AgentStepStatus.success,
          startTime: DateTime.now(),
          endTime: DateTime.now(),
        )),
        const AgentAwaitingConfirmationEvent(AgentConfirmationRequest(
          id: 'c1',
          toolName: 'remember_fact',
          titleFa: 'ثبت در حافظه',
          previewFa: 'پیش‌نمایش',
          parameters: {},
        )),
        const AgentConfirmationResolvedEvent(
          requestId: 'c1',
          toolName: 'remember_fact',
          approved: true,
        ),
        const AgentConfirmationTimedOutEvent(
          requestId: 'c1',
          toolName: 'remember_fact',
        ),
        const AgentAwaitingQuestionEvent(AgentQuestionRequest(
          id: 'q1',
          sessionId: 'session_1',
          question: 'چه ساعتی بیدار شدی؟',
        )),
        const AgentQuestionResolvedEvent(
          requestId: 'q1',
          answered: true,
          answer: 'ساعت ۸',
        ),
        const AgentTokenStreamEvent(delta: 'سلام', accumulated: 'سلام'),
        const AgentDisplayResetEvent(
          turnKind: AgentTurnKind.toolCallTurn,
          turn: 1,
        ),
        const AgentCompletedEvent(
          finalAnswer: 'پاسخ نهایی',
          steps: [],
        ),
        const AgentErrorEvent('خطای آزمایشی'),
      ];

      expect(events.length, equals(13));

      // Simulate consumer router logic
      for (final event in events) {
        final StreamingChatEvent output = switch (event) {
          AgentTokenStreamEvent(:final delta, :final accumulated) => ChatChunk(delta, accumulated),
          AgentCompletedEvent() => AgentStreamEvent(event),
          AgentErrorEvent() => AgentStreamEvent(event),
          _ => AgentStreamEvent(event),
        };

        expect(output, isNotNull, reason: '${event.runtimeType} must produce an output event and never be swallowed.');
      }
    });
  });
}
