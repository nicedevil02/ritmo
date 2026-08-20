import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

class RecordingWebViewController extends Fake implements WebViewController {
  final List<String> executedScripts = [];

  @override
  Future<void> runJavaScript(String javaScript) async {
    executedScripts.add(javaScript);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatGptWebBridgeManager manager;
  late RecordingWebViewController controller;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
    controller = RecordingWebViewController();
    manager.setTestState(
      status: ChatGptBridgeStatus.generating,
      controller: controller,
    );
  });

  tearDown(() {
    manager.disposeWebView();
  });

  group('WEB-10: Safe One-Time Resend With Repetition Protection', () {
    test(
      'triggers safe one-time resend when 0 tokens received and attempts is 0',
      () async {
        final req = PendingWebBridgeRequest(
          requestId: 'req_resend_1',
          promptHash: 'h1',
          promptText: 'پیام مهم کاربر',
          sentAt: DateTime.now(),
          stage: PendingRequestStage.awaitingFirstToken,
          receivedLength: 0,
          resendAttempts: 0,
        );
        manager.setTestPendingRequest(req);
        manager.setTestRequestId('req_resend_1');

        await manager.handleResendRequiredForTest();

        expect(req.resendAttempts, equals(1));
        expect(req.stage, equals(PendingRequestStage.sending));
        expect(controller.executedScripts, isNotEmpty);
        expect(
          controller.executedScripts.any((s) => s.contains('req_resend_1')),
          isTrue,
        );
        expect(manager.status, equals(ChatGptBridgeStatus.generating));
      },
    );

    test(
      'refuses resend if tokens were already received (prevents duplicate assistant messages)',
      () async {
        final req = PendingWebBridgeRequest(
          requestId: 'req_resend_2',
          promptHash: 'h2',
          promptText: 'پیام کاربر',
          sentAt: DateTime.now(),
          stage: PendingRequestStage.streaming,
          receivedLength: 25,
          resendAttempts: 0,
        );
        manager.setTestPendingRequest(req);
        manager.setTestRequestId('req_resend_2');

        await manager.handleResendRequiredForTest();

        expect(controller.executedScripts, isEmpty);
        expect(manager.status, equals(ChatGptBridgeStatus.ready));
      },
    );

    test('refuses second resend if already attempted once', () async {
      final req = PendingWebBridgeRequest(
        requestId: 'req_resend_3',
        promptHash: 'h3',
        promptText: 'پیام کاربر',
        sentAt: DateTime.now(),
        stage: PendingRequestStage.sending,
        receivedLength: 0,
        resendAttempts: 1,
      );
      manager.setTestPendingRequest(req);
      manager.setTestRequestId('req_resend_3');

      await manager.handleResendRequiredForTest();

      expect(controller.executedScripts, isEmpty);
      expect(manager.status, equals(ChatGptBridgeStatus.ready));
    });
  });
}
