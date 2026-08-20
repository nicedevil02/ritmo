import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_exception.dart';

void main() {
  late ChatGptWebBridgeManager manager;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
    BridgeTraceLog.instance.clear();
  });

  tearDown(() {
    manager.resetStateForTest();
  });

  group('DET-35: Prevent Infinite Loading on Unhandled Stream Errors', () {
    test('Bridge fails gracefully on error and resets status to ready without hanging in generating', () async {
      final streamCtrl = StreamController<String>.broadcast();
      addTearDown(streamCtrl.close);

      manager.setTestState(
        status: ChatGptBridgeStatus.generating,
        streamController: streamCtrl,
      );
      manager.setTestRequestId('req_error_35');

      expect(manager.statusNotifier.value, equals(ChatGptBridgeStatus.generating));

      // Trigger failGeneration with an exception
      manager.failGenerationForTest(WebBridgeException.timeout());

      await Future.delayed(Duration.zero);

      expect(manager.statusNotifier.value, equals(ChatGptBridgeStatus.ready));
      expect(streamCtrl.isClosed, isTrue);
    });

    test('cancelCurrentStream cleanly resets generating state and closes current controller', () async {
      final streamCtrl = StreamController<String>.broadcast();
      addTearDown(streamCtrl.close);

      manager.setTestState(
        status: ChatGptBridgeStatus.generating,
        streamController: streamCtrl,
      );
      manager.setTestRequestId('req_cancel_35');

      expect(manager.statusNotifier.value, equals(ChatGptBridgeStatus.generating));

      manager.cancelCurrentStream();

      expect(manager.statusNotifier.value, equals(ChatGptBridgeStatus.ready));
      expect(streamCtrl.isClosed, isTrue);
    });
  });
}
