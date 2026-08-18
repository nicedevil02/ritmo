import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
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

  group('A-53: End-to-End Happy Path Web Bridge Stream Cycle', () {
    test('full lifecycle: ready -> generating -> first_token -> chunks -> done -> ready', () async {
      final streamCtrl = StreamController<String>.broadcast();

      // 1. Initial State
      manager.setStatusForTest(ChatGptBridgeStatus.booting);
      expect(manager.status, ChatGptBridgeStatus.booting);

      // 2. JS Bridge reports ready
      manager.handleJsMessageForTest(
        const JavaScriptMessage(
          message: '{"type":"ready","version":8,"source":"js_boot"}',
        ),
      );
      expect(manager.status, ChatGptBridgeStatus.ready);

      // 3. User sends prompt
      const requestId = 'req_e2e_001';
      final req = PendingWebBridgeRequest(
        requestId: requestId,
        promptHash: 'hash_e2e_001',
        promptText: 'برنامه امروز من را تنظیم کن',
        sentAt: DateTime.now(),
        stage: PendingRequestStage.sending,
      );
      manager.setTestPendingRequest(req);
      manager.setStatusForTest(ChatGptBridgeStatus.generating);
      manager.setCurrentRequestIdForTest(requestId);
      manager.setTestState(streamController: streamCtrl);

      // 4. First token event arrives
      manager.handleJsMessageForTest(
        const JavaScriptMessage(
          message: '{"type":"first_token","latencyMs":450,"source":"fetch","requestId":"req_e2e_001"}',
        ),
      );
      expect(manager.pendingRequest?.stage, PendingRequestStage.streaming);

      // 5. Chunks arrive via SSE
      manager.handleJsMessageForTest(
        const JavaScriptMessage(
          message: '{"type":"chunk","delta":"سلام! ","fullText":"سلام! ","source":"fetch","requestId":"req_e2e_001"}',
        ),
      );
      expect(manager.accumulator.text, 'سلام! ');
      expect(manager.pendingRequest?.stage, PendingRequestStage.streaming);

      manager.handleJsMessageForTest(
        const JavaScriptMessage(
          message: '{"type":"chunk","delta":"برنامه روز شما آماده است: ","fullText":"سلام! برنامه روز شما آماده است: ","source":"fetch","requestId":"req_e2e_001"}',
        ),
      );
      expect(manager.accumulator.text, 'سلام! برنامه روز شما آماده است: ');

      manager.handleJsMessageForTest(
        const JavaScriptMessage(
          message: '{"type":"chunk","delta":"۱. ورزش صبحگاهی","fullText":"سلام! برنامه روز شما آماده است: ۱. ورزش صبحگاهی","source":"fetch","requestId":"req_e2e_001"}',
        ),
      );
      expect(manager.accumulator.text, 'سلام! برنامه روز شما آماده است: ۱. ورزش صبحگاهی');

      // 6. Done event terminates stream
      manager.handleJsMessageForTest(
        const JavaScriptMessage(
          message: '{"type":"done","fullText":"سلام! برنامه روز شما آماده است: ۱. ورزش صبحگاهی","source":"fetch","requestId":"req_e2e_001"}',
        ),
      );

      expect(manager.status, ChatGptBridgeStatus.ready);
      expect(manager.accumulator.text, 'سلام! برنامه روز شما آماده است: ۱. ورزش صبحگاهی');
    });
  });
}
