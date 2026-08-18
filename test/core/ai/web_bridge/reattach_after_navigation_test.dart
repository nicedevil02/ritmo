import 'package:flutter_test/flutter_test.dart';
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

  group('WEB-04: Re-attach and Resume Watcher After Navigation', () {
    test('handlePageFinished without pending request injects script without incrementing reload count', () async {
      manager.setTestState(status: ChatGptBridgeStatus.ready);

      await manager.handlePageFinished('https://chatgpt.com/', controller);

      expect(controller.executedScripts, isNotEmpty);
      expect(manager.navigationReloadCount, equals(0));
    });

    test('handlePageFinished with pending request re-injects script and triggers resume hook', () async {
      manager.setTestState(status: ChatGptBridgeStatus.generating);

      await manager.handlePageFinished('https://chatgpt.com/c/123', controller);

      expect(manager.navigationReloadCount, equals(1));
      expect(controller.executedScripts.length, greaterThanOrEqualTo(2));
      expect(controller.executedScripts.any((s) => s.contains('__ritmo_resume')), isTrue);
    });

    test('handlePageFinished aborts stream if reload count exceeds 3 (infinite reload loop guard)', () async {
      manager.setTestState(status: ChatGptBridgeStatus.generating);

      // 1st reload
      await manager.handlePageFinished('https://chatgpt.com/c/123', controller);
      expect(manager.navigationReloadCount, equals(1));

      // 2nd reload
      await manager.handlePageFinished('https://chatgpt.com/c/123', controller);
      expect(manager.navigationReloadCount, equals(2));

      // 3rd reload
      await manager.handlePageFinished('https://chatgpt.com/c/123', controller);
      expect(manager.navigationReloadCount, equals(3));

      // 4th reload (exceeds threshold of 3)
      await manager.handlePageFinished('https://chatgpt.com/c/123', controller);

      // Status transitioned to ready (failGeneration called) and count reset
      expect(manager.status, equals(ChatGptBridgeStatus.ready));
      expect(manager.navigationReloadCount, equals(0));
    });
  });
}
