import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_bridge_timeouts.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatGptWebBridgeManager manager;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
  });

  tearDown(() {
    manager.disposeWebView();
  });

  group('WEB-27: Single Master Timer Architecture', () {
    test('setupBridgeScript removes aggressive 35000ms premature failure check', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('totalDuration > 35000'), isFalse);
    });

    test('ChatGptWebBridgeManager master timer uses ChatGptBridgeTimeouts.generationTimeout (90s)', () {
      expect(
        ChatGptWebBridgeManager.generationTimeout,
        equals(ChatGptBridgeTimeouts.generationTimeout),
      );
      expect(ChatGptWebBridgeManager.generationTimeout.inSeconds, equals(90));
    });

    test('cancelCurrentStream immediately resets active generation and timer states', () {
      final streamController = StreamController<String>();
      addTearDown(streamController.close);
      manager.setTestState(
        status: ChatGptBridgeStatus.generating,
        streamController: streamController,
      );
      manager.setTestRequestId('req_cancel_1');

      manager.cancelCurrentStream();

      expect(manager.status, equals(ChatGptBridgeStatus.ready));
      expect(manager.currentRequestId, isNull);
      expect(manager.pendingRequest, isNull);
    });
  });
}
