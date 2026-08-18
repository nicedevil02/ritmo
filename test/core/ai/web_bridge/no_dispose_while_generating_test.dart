import 'package:flutter/widgets.dart';
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
  });

  tearDown(() {
    manager.disposeWebView();
  });

  group('WEB-06: Protection of In-Flight Generation Against Inactivity & Lifecycle Disposals', () {
    test('didChangeAppLifecycleState(paused) does NOT dispose controller while generating', () {
      manager.setTestState(
        status: ChatGptBridgeStatus.generating,
        controller: fakeController,
      );

      manager.didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(manager.controller, equals(fakeController));
      expect(manager.status, equals(ChatGptBridgeStatus.generating));
    });

    test('didChangeAppLifecycleState(detached) does NOT dispose controller while generating', () {
      manager.setTestState(
        status: ChatGptBridgeStatus.generating,
        controller: fakeController,
      );

      manager.didChangeAppLifecycleState(AppLifecycleState.detached);

      expect(manager.controller, equals(fakeController));
      expect(manager.status, equals(ChatGptBridgeStatus.generating));
    });

    test('didChangeAppLifecycleState(paused) disposes controller when in ready status', () {
      manager.setTestState(
        status: ChatGptBridgeStatus.ready,
        controller: fakeController,
      );

      manager.didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(manager.controller, isNull);
      expect(manager.status, equals(ChatGptBridgeStatus.idle));
    });
  });
}
