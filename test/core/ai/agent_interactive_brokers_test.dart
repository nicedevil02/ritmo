import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_policy_gate.dart';

void main() {
  group('Agent Interactive Brokers Tests (T29)', () {
    tearDown(() {
      AgentConfirmationBroker.instance.cancelAll();
      AgentQuestionBroker.instance.cancelAll();
    });

    test('AgentConfirmationBroker resolves upon approve', () async {
      const req = AgentConfirmationRequest(
        id: 'conf_1',
        toolName: 'create_new_routine',
        titleFa: 'ایجاد روتین',
        previewFa: 'ساخت روتین جدید',
        parameters: {'title': 'مطالعه'},
      );

      final future = AgentConfirmationBroker.instance.ask(
        req,
        timeout: const Duration(seconds: 5),
      );

      expect(AgentConfirmationBroker.instance.hasPending, isTrue);
      expect(AgentConfirmationBroker.instance.pending.value?.id, 'conf_1');

      final approved = AgentConfirmationBroker.instance.approve('conf_1');
      expect(approved, isTrue);

      final response = await future;
      expect(response.approved, isTrue);
      expect(AgentConfirmationBroker.instance.hasPending, isFalse);
    });

    test(
      'AgentConfirmationBroker cancels cleanly with cancelAll without leaking',
      () async {
        const req = AgentConfirmationRequest(
          id: 'conf_2',
          toolName: 'create_new_routine',
          titleFa: 'ایجاد روتین',
          previewFa: 'ساخت روتین جدید',
          parameters: {'title': 'ورزش'},
        );

        final future = AgentConfirmationBroker.instance.ask(
          req,
          timeout: const Duration(seconds: 10),
        );

        expect(AgentConfirmationBroker.instance.hasPending, isTrue);

        AgentConfirmationBroker.instance.cancelAll(reasonFa: 'بسته شدن شیت');

        final response = await future;
        expect(response.approved, isFalse);
        expect(response.reasonFa, 'بسته شدن شیت');
        expect(AgentConfirmationBroker.instance.hasPending, isFalse);
      },
    );

    test('AgentQuestionBroker resolves upon user respond', () async {
      const req = AgentQuestionRequest(
        id: 'q_1',
        sessionId: 'session_1',
        question: 'ساعت روتین چه زمانی باشد؟',
        options: ['07:00', '08:00'],
      );

      final future = AgentQuestionBroker.instance.ask(
        req,
        timeout: const Duration(seconds: 5),
      );

      expect(AgentQuestionBroker.instance.hasPending, isTrue);
      expect(AgentQuestionBroker.instance.pending.value?.id, 'q_1');

      final responded = AgentQuestionBroker.instance.respond('q_1', '07:30');
      expect(responded, isTrue);

      final response = await future;
      expect(response.answered, isTrue);
      expect(response.answer, '07:30');
      expect(AgentQuestionBroker.instance.hasPending, isFalse);
    });

    test(
      'AgentQuestionBroker cancels cleanly with cancelAll without leaking',
      () async {
        const req = AgentQuestionRequest(
          id: 'q_2',
          sessionId: 'session_1',
          question: 'عنوان درس چیست؟',
        );

        final future = AgentQuestionBroker.instance.ask(
          req,
          timeout: const Duration(seconds: 10),
        );

        expect(AgentQuestionBroker.instance.hasPending, isTrue);

        AgentQuestionBroker.instance.cancelAll(reasonFa: 'پایان گفتگو');

        final response = await future;
        expect(response.answered, isFalse);
        expect(response.reasonFa, 'پایان گفتگو');
        expect(AgentQuestionBroker.instance.hasPending, isFalse);
      },
    );
  });
}
