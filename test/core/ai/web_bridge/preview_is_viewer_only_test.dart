import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

class FakeWebViewController extends Fake implements WebViewController {
  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setUserAgent(String? userAgent) async {}

  @override
  Future<void> addJavaScriptChannel(
    String name, {
    required void Function(JavaScriptMessage) onMessageReceived,
  }) async {}

  @override
  Future<void> setNavigationDelegate(NavigationDelegate delegate) async {}

  @override
  Future<void> loadRequest(
    Uri uri, {
    LoadRequestMethod method = LoadRequestMethod.get,
    Map<String, String> headers = const <String, String>{},
    Uint8List? body,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatGptWebBridgeManager manager;
  late FakeWebViewController fakeController;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
    fakeController = FakeWebViewController();
    ChatGptWebBridgeManager.controllerCreationCount = 0;
    ChatGptWebBridgeManager.testControllerFactory = () =>
        FakeWebViewController();
  });

  tearDown(() {
    manager.disposeWebView();
    ChatGptWebBridgeManager.testControllerFactory = null;
  });

  group(
    'WEB-02: Preview Is Viewer Only (attachViewer does not boot unless idle)',
    () {
      test(
        'attachViewer in generating state returns controller and creates no new controller',
        () {
          manager.setTestState(
            status: ChatGptBridgeStatus.generating,
            controller: fakeController,
          );

          final initialCreationCount =
              ChatGptWebBridgeManager.controllerCreationCount;
          final controller = manager.attachViewer();

          expect(controller, equals(fakeController));
          expect(
            ChatGptWebBridgeManager.controllerCreationCount,
            equals(initialCreationCount),
          );
          expect(manager.status, equals(ChatGptBridgeStatus.generating));
        },
      );

      test(
        'attachViewer in ready state returns controller and creates no new controller',
        () {
          manager.setTestState(
            status: ChatGptBridgeStatus.ready,
            controller: fakeController,
          );

          final initialCreationCount =
              ChatGptWebBridgeManager.controllerCreationCount;
          final controller = manager.attachViewer();

          expect(controller, equals(fakeController));
          expect(
            ChatGptWebBridgeManager.controllerCreationCount,
            equals(initialCreationCount),
          );
          expect(manager.status, equals(ChatGptBridgeStatus.ready));
        },
      );

      test(
        'attachViewer in cloudflareChallenge state returns controller without rebooting',
        () {
          manager.setTestState(
            status: ChatGptBridgeStatus.cloudflareChallenge,
            controller: fakeController,
          );

          final initialCreationCount =
              ChatGptWebBridgeManager.controllerCreationCount;
          final controller = manager.attachViewer();

          expect(controller, equals(fakeController));
          expect(
            ChatGptWebBridgeManager.controllerCreationCount,
            equals(initialCreationCount),
          );
          expect(
            manager.status,
            equals(ChatGptBridgeStatus.cloudflareChallenge),
          );
        },
      );

      test('attachViewer in idle state initiates lazy ensureBooted', () async {
        manager.setTestState(status: ChatGptBridgeStatus.idle);

        final controller = manager.attachViewer();
        expect(controller, isNotNull);
        expect(manager.status, equals(ChatGptBridgeStatus.booting));
      });
    },
  );
}
