import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatGptWebBridgeManager manager;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
    manager.resetStateForTest();
  });

  tearDown(() {
    manager.disposeWebView();
  });

  group('WEB-17: Event Source Tagging & Dual SSE/DOM Coordination', () {
    test(
      'chunk with source sse sets hasActiveSseStream and updates lastChunkSource',
      () {
        manager.setTestState(status: ChatGptBridgeStatus.generating);
        manager.setTestRequestId('req_src_1');

        final sseChunk = JavaScriptMessage(
          message: jsonEncode({
            'type': 'chunk',
            'delta': 'سلام ',
            'fullText': 'سلام ',
            'requestId': 'req_src_1',
            'source': 'sse',
          }),
        );

        manager.handleJsMessageForTest(sseChunk);

        expect(manager.hasActiveSseStream, isTrue);
        expect(manager.lastChunkSource, equals('sse'));
      },
    );

    test(
      'chunk with source dom updates lastChunkSource without duplicating text in stream',
      () async {
        final streamController = StreamController<String>();
        final emittedItems = <String>[];
        final sub = streamController.stream.listen(emittedItems.add);

        manager.setTestState(
          status: ChatGptBridgeStatus.generating,
          streamController: streamController,
        );
        manager.setTestRequestId('req_src_2');

        final sseChunk = JavaScriptMessage(
          message: jsonEncode({
            'type': 'chunk',
            'fullText': 'سلام کاربر',
            'requestId': 'req_src_2',
            'source': 'sse',
          }),
        );
        manager.handleJsMessageForTest(sseChunk);

        final domChunk = JavaScriptMessage(
          message: jsonEncode({
            'type': 'chunk',
            'fullText': 'سلام کاربر',
            'requestId': 'req_src_2',
            'source': 'dom',
          }),
        );
        manager.handleJsMessageForTest(domChunk);

        await Future.delayed(Duration.zero);
        expect(manager.lastChunkSource, equals('dom'));
        expect(manager.accumulator.text, equals('سلام کاربر'));

        if (ChatGptWebBridgeManager.enableWebBridgeStreaming) {
          expect(emittedItems, equals(['سلام کاربر']));
        } else {
          // When streaming is disabled, full text is delivered on completion
          final doneMsg = JavaScriptMessage(
            message: jsonEncode({
              'type': 'done',
              'fullText': 'سلام کاربر',
              'requestId': 'req_src_2',
              'source': 'sse',
            }),
          );
          manager.handleJsMessageForTest(doneMsg);
          await pumpEventQueue();
          expect(emittedItems, equals(['سلام کاربر']));
        }

        await sub.cancel();
        if (!streamController.isClosed) await streamController.close();
      },
    );

    test('stream completion resets source tracking state', () {
      manager.setTestState(status: ChatGptBridgeStatus.generating);
      manager.setTestRequestId('req_src_3');

      final sseChunk = JavaScriptMessage(
        message: jsonEncode({
          'type': 'chunk',
          'delta': 'پاسخ کامل',
          'fullText': 'پاسخ کامل',
          'requestId': 'req_src_3',
          'source': 'sse',
        }),
      );
      manager.handleJsMessageForTest(sseChunk);
      expect(manager.hasActiveSseStream, isTrue);

      final doneMsg = JavaScriptMessage(
        message: jsonEncode({
          'type': 'done',
          'fullText': 'پاسخ کامل',
          'requestId': 'req_src_3',
          'source': 'sse',
        }),
      );
      manager.handleJsMessageForTest(doneMsg);

      expect(manager.hasActiveSseStream, isFalse);
      expect(manager.lastChunkSource, isNull);
    });
  });
}
