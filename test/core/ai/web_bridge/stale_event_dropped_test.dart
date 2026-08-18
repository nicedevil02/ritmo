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

  group('WEB-07: Global Request ID Correlation & Stale Event Dropping', () {
    test('stale done event from older requestId is dropped without closing generation', () {
      manager.setTestState(status: ChatGptBridgeStatus.generating);
      manager.setTestRequestId('req_active_123');

      // Stale done event for past request
      final staleDone = JavaScriptMessage(
        message: jsonEncode({
          'type': 'done',
          'fullText': 'پاسخ قدیمی که نباید بیاید',
          'requestId': 'req_stale_000',
          'source': 'dom',
        }),
      );

      manager.handleJsMessageForTest(staleDone);

      // Should remain generating because stale event was dropped!
      expect(manager.status, equals(ChatGptBridgeStatus.generating));
      expect(manager.currentRequestId, equals('req_active_123'));
    });

    test('matching done event for active requestId is processed normally', () {
      manager.setTestState(status: ChatGptBridgeStatus.generating);
      manager.setTestRequestId('req_active_123');

      // Matching done event
      final matchingDone = JavaScriptMessage(
        message: jsonEncode({
          'type': 'done',
          'fullText': 'پاسخ درست و فعال',
          'requestId': 'req_active_123',
          'source': 'dom',
        }),
      );

      manager.handleJsMessageForTest(matchingDone);

      // Transitions to ready and clears currentRequestId
      expect(manager.status, equals(ChatGptBridgeStatus.ready));
      expect(manager.currentRequestId, isNull);
    });

    test('request-independent events (ready, cloudflare) are processed regardless of requestId', () {
      manager.setTestState(status: ChatGptBridgeStatus.idle);

      final readyEvent = JavaScriptMessage(
        message: jsonEncode({
          'type': 'ready',
          'version': 7,
          'isWarm': true,
        }),
      );

      manager.handleJsMessageForTest(readyEvent);

      expect(manager.status, equals(ChatGptBridgeStatus.ready));
    });

    test('buildSendPromptScript injects prompt and requestId into JS call', () {
      final script = ChatGptJsInjector.buildSendPromptScript(
        'سلام ریتمو',
        requestId: 'req_test_999',
      );

      expect(script.contains('req_test_999'), isTrue);
      expect(script.contains('سلام ریتمو'), isTrue);
    });
  });
}
