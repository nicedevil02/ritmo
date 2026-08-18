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

  group('WEB-23: Page Auth State Detection', () {
    test('setupBridgeScript contains checkAuthState and auth_required notification logic', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('function checkAuthState()'), isTrue);
      expect(script.contains('window.__ritmo_checkAuthState'), isTrue);
      expect(script.contains("notifyFlutter('auth_required'"), isTrue);
      expect(script.contains('RITMO_SELECTORS.loginButton'), isTrue);
    });

    test('auth_required message updates isAuthenticated to false and fails active generation', () {
      manager.setTestState(status: ChatGptBridgeStatus.generating);
      manager.setTestRequestId('req_auth_1');
      manager.setTestPendingRequest(
        PendingWebBridgeRequest(
          requestId: 'req_auth_1',
          promptHash: 'h_auth',
          promptText: 'سلام',
          sentAt: DateTime.now(),
        ),
      );

      final msg = JavaScriptMessage(
        message: jsonEncode({
          'type': 'auth_required',
          'hasLoginButton': true,
          'currentPath': '/auth/login',
          'source': 'lifecycle',
        }),
      );

      manager.handleJsMessageForTest(msg);

      expect(manager.isAuthenticated, isFalse);
      expect(manager.status, equals(ChatGptBridgeStatus.ready));
      expect(manager.pendingRequest, isNull);
    });

    test('ready event updates isAuthenticated to true', () {
      manager.setTestAuthenticated(false);

      final readyMsg = JavaScriptMessage(
        message: jsonEncode({
          'type': 'ready',
          'version': 7,
          'hasComposer': true,
        }),
      );

      manager.handleJsMessageForTest(readyMsg);

      expect(manager.isAuthenticated, isTrue);
    });
  });
}
