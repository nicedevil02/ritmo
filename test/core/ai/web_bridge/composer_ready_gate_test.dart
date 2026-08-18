import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PollingWebViewController extends Fake implements WebViewController {
  int pollCount = 0;
  final int readyAfterAttempts;

  PollingWebViewController({this.readyAfterAttempts = 2});

  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async {
    pollCount++;
    if (pollCount >= readyAfterAttempts) {
      return jsonEncode({'ready': true});
    }
    return jsonEncode({'ready': false, 'reason': 'disabled'});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatGptWebBridgeManager manager;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
  });

  tearDown(() {
    manager.disposeWebView();
  });

  group('WEB-12: Composer Readiness Gate', () {
    test('setupBridgeScript contains __ritmo_checkComposerReady implementation', () {
      final script = ChatGptJsInjector.setupBridgeScript;
      expect(script.contains('window.__ritmo_checkComposerReady'), isTrue);
      expect(script.contains('prompt-textarea'), isTrue);
    });

    test('waitForComposerReady polls until composer becomes ready', () async {
      final controller = PollingWebViewController(readyAfterAttempts: 2);
      manager.setTestState(controller: controller);

      final isReady = await manager.waitForComposerReady(
        timeout: const Duration(seconds: 2),
      );

      expect(isReady, isTrue);
      expect(controller.pollCount, greaterThanOrEqualTo(2));
    });

    test('waitForComposerReady returns false on timeout if never ready', () async {
      final controller = PollingWebViewController(readyAfterAttempts: 999);
      manager.setTestState(controller: controller);

      final isReady = await manager.waitForComposerReady(
        timeout: const Duration(milliseconds: 500),
      );

      expect(isReady, isFalse);
    });
  });
}
