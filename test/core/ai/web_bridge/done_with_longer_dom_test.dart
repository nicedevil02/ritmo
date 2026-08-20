import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatGptWebBridgeManager manager;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
    BridgeTraceLog.instance.clear();
  });

  tearDown(() {
    manager.cancelTimersForTesting();
    manager.disposeWebView();
    BridgeTraceLog.instance.clear();
  });

  group('A-89: Done with Longer DOM Acceptance', () {
    test(
      'DOM done event with longer fullText is accepted as harvest even if SSE is locked',
      () async {
        final activeController = StreamController<String>();
        final receivedChunks = <String>[];
        final sub = activeController.stream.listen(receivedChunks.add);

        manager.setTestState(
          status: ChatGptBridgeStatus.generating,
          streamController: activeController,
        );
        manager.setTestRequestId('req_longer_dom');

        // 1. SSE chunk locks source to SSE
        manager.handleJsMessageForTest(
          JavaScriptMessage(
            message: jsonEncode({
              'type': 'chunk',
              'delta': 'سلام از طریق SSE',
              'source': 'sse',
              'requestId': 'req_longer_dom',
            }),
          ),
        );

        expect(manager.lockedSource?.name, equals('sse'));
        expect(manager.accumulator.length, equals(16));

        // 2. DOM sends done event with longer fullText (e.g. 50 chars)
        const longerDomText =
            'سلام از طریق SSE و ادامهٔ کامل پاسخ که در DOM قرار دارد.';
        manager.handleJsMessageForTest(
          JavaScriptMessage(
            message: jsonEncode({
              'type': 'done',
              'fullText': longerDomText,
              'source': 'dom',
              'requestId': 'req_longer_dom',
            }),
          ),
        );

        // 3. Manager should accept longer text and transition to ready
        await pumpEventQueue();
        expect(manager.status, equals(ChatGptBridgeStatus.ready));
        expect(receivedChunks.join(''), equals(longerDomText));

        manager.cancelTimersForTesting();
        await activeController.close();
        await sub.cancel();
      },
    );
  });
}
