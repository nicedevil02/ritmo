import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatGptWebBridgeManager manager;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
    manager.resetStateForTest();
    BridgeTraceLog.instance.clear();
  });

  tearDown(() {
    manager.disposeWebView();
  });

  group('A-50: Source Arbitration and Source Locking', () {
    test('locks to the first SSE/network source and drops competing DOM chunks', () async {
      final streamCtrl = StreamController<String>.broadcast();
      final req = PendingWebBridgeRequest(
        requestId: 'req_arb_100',
        promptHash: 'hash_100',
        promptText: 'سلام دستیار',
        sentAt: DateTime.now(),
        stage: PendingRequestStage.sending,
      );
      manager.setTestPendingRequest(req);
      manager.setStatusForTest(ChatGptBridgeStatus.generating);
      manager.setCurrentRequestIdForTest('req_arb_100');
      manager.setTestState(streamController: streamCtrl);

      // 1. First event arrives via fetch SSE hook
      manager.handleJsMessageForTest(
        const JavaScriptMessage(
          message: '{"type":"chunk","delta":"سلام! ","fullText":"سلام! ","source":"fetch","requestId":"req_arb_100"}',
        ),
      );

      expect(manager.lockedSource, BridgeSource.fetch);
      expect(manager.accumulator.text, 'سلام! ');

      // 2. Competing DOM event arrives with fullText
      manager.handleJsMessageForTest(
        const JavaScriptMessage(
          message: '{"type":"chunk","delta":"سلام! من ریتمو هستم","fullText":"سلام! من ریتمو هستم","source":"dom","requestId":"req_arb_100"}',
        ),
      );

      // DOM event must be dropped because source is locked to fetch
      expect(manager.lockedSource, BridgeSource.fetch);
      expect(manager.accumulator.text, 'سلام! ');

      // 3. Second event from locked fetch source is processed normally
      manager.handleJsMessageForTest(
        const JavaScriptMessage(
          message: '{"type":"chunk","delta":"من ریتمو هستم.","fullText":"سلام! من ریتمو هستم.","source":"fetch","requestId":"req_arb_100"}',
        ),
      );

      expect(manager.accumulator.text, 'سلام! من ریتمو هستم.');

      // Verify trace log recorded source_locked
      final traceEntries = BridgeTraceLog.instance.entries;
      expect(traceEntries.any((e) => e.type == 'source_locked'), isTrue);
    });

    test('resets locked source upon completion or new prompt', () {
      manager.setLockedSourceForTest(BridgeSource.fetch);
      expect(manager.lockedSource, BridgeSource.fetch);

      manager.resetStateForTest();
      expect(manager.lockedSource, isNull);
    });
  });
}
