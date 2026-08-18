import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
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
  });

  tearDown(() {
    manager.disposeWebView();
  });

  group('WEB-09: Resume Response Stream After Document Navigation', () {
    test('setupBridgeScript contains __ritmo_resume implementation', () {
      final script = ChatGptJsInjector.setupBridgeScript;
      expect(script.contains('window.__ritmo_resume'), isTrue);
      expect(script.contains('resend_required'), isTrue);
      expect(script.contains('resumed'), isTrue);
    });

    test('handlePageFinished passes pending request JSON payload to __ritmo_resume', () async {
      manager.setTestState(status: ChatGptBridgeStatus.generating);
      manager.setTestRequestId('req_nav_789');
      manager.setTestPendingRequest(
        PendingWebBridgeRequest(
          requestId: 'req_nav_789',
          promptHash: 'h789',
          promptText: 'خلاصه سوال کاربر بعد از ریدایرکت',
          sentAt: DateTime.now(),
          stage: PendingRequestStage.awaitingFirstToken,
        ),
      );

      await manager.handlePageFinished('https://chatgpt.com/c/new-convo-id', controller);

      final resumeScript = controller.executedScripts.lastWhere(
        (s) => s.contains('window.__ritmo_resume('),
        orElse: () => '',
      );

      expect(resumeScript, isNotEmpty);
      expect(resumeScript.contains('req_nav_789'), isTrue);
      expect(resumeScript.contains('awaitingFirstToken'), isTrue);
    });

    test('resumed event transitions stage to streaming and preserves active stream', () {
      manager.setTestState(status: ChatGptBridgeStatus.generating);
      manager.setTestRequestId('req_nav_789');
      final pendingReq = PendingWebBridgeRequest(
        requestId: 'req_nav_789',
        promptHash: 'h789',
        promptText: 'متن پرامپت',
        sentAt: DateTime.now(),
        stage: PendingRequestStage.awaitingFirstToken,
      );
      manager.setTestPendingRequest(pendingReq);

      final resumedMsg = JavaScriptMessage(
        message: jsonEncode({
          'type': 'resumed',
          'stage': 'streaming',
          'requestId': 'req_nav_789',
          'source': 'dom',
        }),
      );

      manager.handleJsMessageForTest(resumedMsg);

      expect(manager.status, equals(ChatGptBridgeStatus.generating));
      expect(manager.pendingRequest?.stage, equals(PendingRequestStage.streaming));
    });
  });
}
