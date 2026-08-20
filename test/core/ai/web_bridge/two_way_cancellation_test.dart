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
    manager.setTestState(
      status: ChatGptBridgeStatus.generating,
      controller: controller,
    );
  });

  tearDown(() {
    manager.disposeWebView();
  });

  group('WEB-11: Two-Way Cancellation & Web Stop Trigger', () {
    test(
      'setupBridgeScript contains __ritmo_cancelGeneration implementation',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;
        expect(script.contains('window.__ritmo_cancelGeneration'), isTrue);
        expect(script.contains('stop-button'), isTrue);
      },
    );

    test('cancelScript invokes __ritmo_cancelGeneration', () {
      expect(
        ChatGptJsInjector.cancelScript.contains(
          'window.__ritmo_cancelGeneration()',
        ),
        isTrue,
      );
    });

    test(
      'cancelCurrentStream sends cancelScript to controller and returns manager to ready',
      () {
        manager.setTestRequestId('req_cancel_test');
        manager.setTestPendingRequest(
          PendingWebBridgeRequest(
            requestId: 'req_cancel_test',
            promptHash: 'h_cancel',
            promptText: 'متن لغو شده',
            sentAt: DateTime.now(),
          ),
        );

        manager.cancelCurrentStream();

        expect(controller.executedScripts, isNotEmpty);
        expect(
          controller.executedScripts.any(
            (s) => s.contains('__ritmo_cancelGeneration'),
          ),
          isTrue,
        );
        expect(manager.status, equals(ChatGptBridgeStatus.ready));
        expect(manager.currentRequestId, isNull);
        expect(manager.pendingRequest, isNull);
      },
    );
  });
}
