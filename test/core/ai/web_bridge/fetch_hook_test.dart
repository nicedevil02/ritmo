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

  group('WEB-13: Global Fetch Interceptor Hook', () {
    test('setupBridgeScript contains fetch interceptor and conversation URL detection', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('var originalFetch = window.fetch;'), isTrue);
      expect(script.contains('/backend-api/conversation'), isTrue);
      expect(script.contains('/backend-anon/conversation'), isTrue);
      expect(script.contains('network_conversation_started'), isTrue);
    });

    test('setupBridgeScript restores original fetch on cleanup', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('window.__ritmo_cleanup'), isTrue);
      expect(script.contains('window.fetch = window.__ritmo_original_fetch'), isTrue);
    });

    test('network_conversation_started event transitions stage from sending to awaitingFirstToken', () {
      manager.setTestState(status: ChatGptBridgeStatus.generating);
      final req = PendingWebBridgeRequest(
        requestId: 'req_net_1',
        promptHash: 'h_net',
        promptText: 'سلام ریتمو',
        sentAt: DateTime.now(),
        stage: PendingRequestStage.sending,
      );
      manager.setTestPendingRequest(req);
      manager.setTestRequestId('req_net_1');

      final netMsg = JavaScriptMessage(
        message: jsonEncode({
          'type': 'network_conversation_started',
          'url': 'https://chatgpt.com/backend-api/conversation',
          'requestId': 'req_net_1',
          'source': 'fetch',
        }),
      );

      manager.handleJsMessageForTest(netMsg);

      expect(manager.pendingRequest?.stage, equals(PendingRequestStage.awaitingFirstToken));
      expect(manager.status, equals(ChatGptBridgeStatus.generating));
    });
  });
}
