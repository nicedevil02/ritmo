import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

class FakeWebViewController extends Fake implements WebViewController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatGptWebBridgeManager manager;
  late FakeWebViewController fakeController;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
    fakeController = FakeWebViewController();
    ChatGptWebBridgeManager.controllerCreationCount = 0;
    ChatGptWebBridgeManager.testControllerFactory = () => FakeWebViewController();
  });

  tearDown(() {
    manager.disposeWebView();
    ChatGptWebBridgeManager.testControllerFactory = null;
  });

  group('WEB-01: No WebView Reboot While Generating or Cloudflare Challenge', () {
    test('ensureBooted returns controller exists and does NOT create controller when generating', () async {
      manager.setTestState(
        status: ChatGptBridgeStatus.generating,
        controller: fakeController,
      );

      final initialCreationCount = ChatGptWebBridgeManager.controllerCreationCount;

      final res1 = await manager.ensureBooted();
      expect(res1, isTrue);
      expect(ChatGptWebBridgeManager.controllerCreationCount, equals(initialCreationCount));

      final res2 = await manager.ensureBooted();
      expect(res2, isTrue);
      expect(ChatGptWebBridgeManager.controllerCreationCount, equals(initialCreationCount));
      expect(manager.status, equals(ChatGptBridgeStatus.generating));
    });

    test('ensureBooted preserves controller during cloudflareChallenge without rebooting', () async {
      manager.setTestState(
        status: ChatGptBridgeStatus.cloudflareChallenge,
        controller: fakeController,
      );

      final initialCreationCount = ChatGptWebBridgeManager.controllerCreationCount;

      final res = await manager.ensureBooted();
      expect(res, isTrue);
      expect(ChatGptWebBridgeManager.controllerCreationCount, equals(initialCreationCount));
      expect(manager.status, equals(ChatGptBridgeStatus.cloudflareChallenge));
    });

    test('ensureBooted attaches to in-flight bootCompleter rather than spawning parallel boot', () async {
      final existingCompleter = Completer<bool>();
      manager.setTestState(
        status: ChatGptBridgeStatus.booting,
        bootCompleter: existingCompleter,
      );

      final future = manager.ensureBooted();
      expect(ChatGptWebBridgeManager.controllerCreationCount, equals(0));

      existingCompleter.complete(true);
      final result = await future;
      expect(result, isTrue);
    });
  });
}
