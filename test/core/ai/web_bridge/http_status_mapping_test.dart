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

  group('WEB-16: HTTP Status Code Mapping to Typed Persian Errors', () {
    test('setupBridgeScript contains http_error notification on non-200 responses', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('response.status !== 200'), isTrue);
      expect(script.contains("notifyFlutter('http_error'"), isTrue);
    });

    test('http_error with 429 rate limit closes stream and resets status', () {
      manager.setTestState(status: ChatGptBridgeStatus.generating);
      manager.setTestRequestId('req_429');
      manager.setTestPendingRequest(
        PendingWebBridgeRequest(
          requestId: 'req_429',
          promptHash: 'h_429',
          promptText: 'سلام',
          sentAt: DateTime.now(),
        ),
      );

      final msg = JavaScriptMessage(
        message: jsonEncode({
          'type': 'http_error',
          'statusCode': 429,
          'requestId': 'req_429',
          'source': 'fetch',
        }),
      );

      manager.handleJsMessageForTest(msg);

      expect(manager.status, equals(ChatGptBridgeStatus.ready));
      expect(manager.pendingRequest, isNull);
    });

    test('http_error with 401 unauthorized closes stream with Persian auth message', () {
      manager.setTestState(status: ChatGptBridgeStatus.generating);
      manager.setTestRequestId('req_401');

      final msg = JavaScriptMessage(
        message: jsonEncode({
          'type': 'http_error',
          'statusCode': 401,
          'requestId': 'req_401',
          'source': 'fetch',
        }),
      );

      manager.handleJsMessageForTest(msg);

      expect(manager.status, equals(ChatGptBridgeStatus.ready));
    });

    test('http_error with 503 service unavailable closes stream with Persian server message', () {
      manager.setTestState(status: ChatGptBridgeStatus.generating);
      manager.setTestRequestId('req_503');

      final msg = JavaScriptMessage(
        message: jsonEncode({
          'type': 'http_error',
          'statusCode': 503,
          'requestId': 'req_503',
          'source': 'fetch',
        }),
      );

      manager.handleJsMessageForTest(msg);

      expect(manager.status, equals(ChatGptBridgeStatus.ready));
    });

    test('stale http_error for old requestId is dropped without aborting active stream', () {
      manager.setTestState(status: ChatGptBridgeStatus.generating);
      manager.setTestRequestId('req_current_active');

      final staleMsg = JavaScriptMessage(
        message: jsonEncode({
          'type': 'http_error',
          'statusCode': 500,
          'requestId': 'req_stale_old',
          'source': 'fetch',
        }),
      );

      manager.handleJsMessageForTest(staleMsg);

      expect(manager.status, equals(ChatGptBridgeStatus.generating));
      expect(manager.currentRequestId, equals('req_current_active'));
    });
  });
}
