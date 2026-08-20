import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatGptWebBridgeManager manager;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
  });

  tearDown(() {
    manager.disposeWebView();
  });

  group('WEB-22: First Token Settle Timing & Stage Transition', () {
    test(
      'setupBridgeScript contains first_token notification logic in SSE and DOM',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(script.contains("notifyFlutter('first_token'"), isTrue);
        expect(
          script.contains('latencyMs: Date.now() - state.startTime'),
          isTrue,
        );
        expect(
          script.contains('latencyMs: Date.now() - streamStartTime'),
          isTrue,
        );
      },
    );

    test(
      'first_token event transitions PendingWebBridgeRequest stage to streaming',
      () {
        manager.setTestState(status: ChatGptBridgeStatus.generating);
        manager.setTestRequestId('req_ttft_1');
        manager.setTestPendingRequest(
          PendingWebBridgeRequest(
            requestId: 'req_ttft_1',
            promptHash: 'h_ttft',
            promptText: 'پرامپت زمانبندی',
            sentAt: DateTime.now(),
            stage: PendingRequestStage.awaitingFirstToken,
          ),
        );

        final msg = JavaScriptMessage(
          message: jsonEncode({
            'type': 'first_token',
            'length': 8,
            'latencyMs': 420,
            'requestId': 'req_ttft_1',
            'source': 'sse',
          }),
        );

        manager.handleJsMessageForTest(msg);

        expect(
          manager.pendingRequest?.stage,
          equals(PendingRequestStage.streaming),
        );
      },
    );
  });
}
