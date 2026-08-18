import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MockDisposalWebViewController extends Fake implements WebViewController {
  bool channelRemoved = false;
  bool blankPageLoaded = false;

  @override
  Future<void> removeJavaScriptChannel(String javaScriptChannelName) async {
    if (javaScriptChannelName == 'RitmoChatBridge') {
      channelRemoved = true;
    }
  }

  @override
  Future<void> loadRequest(
    Uri uri, {
    LoadRequestMethod method = LoadRequestMethod.get,
    Map<String, String> headers = const <String, String>{},
    dynamic body,
  }) async {
    if (uri.toString() == 'about:blank') {
      blankPageLoaded = true;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatGptWebBridgeManager manager;
  late MockDisposalWebViewController mockController;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
    mockController = MockDisposalWebViewController();
  });

  tearDown(() {
    manager.disposeWebView();
    ChatGptWebBridgeManager.testControllerFactory = null;
  });

  group('WEB-30: Safe WebViewController Disposal & Android Lifecycle Protection', () {
    test('disposeWebView safely tears down channel and loads blank page', () async {
      manager.setTestState(
        status: ChatGptBridgeStatus.ready,
        controller: mockController,
      );

      expect(manager.controller, equals(mockController));

      manager.disposeWebView();

      expect(manager.controller, isNull);
      expect(manager.status, equals(ChatGptBridgeStatus.idle));

      // Wait a microtask / tick for unawaited safe disposal to execute
      await Future.delayed(const Duration(milliseconds: 50));

      expect(mockController.channelRemoved, isTrue);
      expect(mockController.blankPageLoaded, isTrue);
    });

    test('forceReboot safely disposes the old controller before attempting recreation', () async {
      final oldController = MockDisposalWebViewController();
      final newController = MockDisposalWebViewController();

      manager.setTestState(
        status: ChatGptBridgeStatus.ready,
        controller: oldController,
      );

      ChatGptWebBridgeManager.testControllerFactory = () => newController;

      // Start forceReboot
      final rebootFuture = manager.forceReboot(reasonFa: 'تست بازنشانی ایمن');

      // Old controller should be immediately disposed with blank page and channel removed
      await Future.delayed(const Duration(milliseconds: 50));
      expect(oldController.channelRemoved, isTrue);
      expect(oldController.blankPageLoaded, isTrue);

      manager.handleJsMessageForTest(const JavaScriptMessage(message: '{"type":"ready"}'));
      await rebootFuture;
    });

    test('handlePageFinished safely ignores stale controller when manager has different controller', () async {
      final activeController = MockDisposalWebViewController();
      final staleController = MockDisposalWebViewController();

      manager.setTestState(
        status: ChatGptBridgeStatus.ready,
        controller: activeController,
      );

      // Call handlePageFinished with stale controller
      await manager.handlePageFinished('https://chatgpt.com/', staleController);

      expect(manager.navigationReloadCount, equals(0));
    });
  });
}
