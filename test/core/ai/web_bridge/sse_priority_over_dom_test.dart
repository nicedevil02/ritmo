import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  late ChatGptWebBridgeManager manager;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
    BridgeTraceLog.instance.clear();
  });

  tearDown(() {
    manager.resetStateForTest();
  });

  group('DET-19: SSE Priority Over DOM Lock', () {
    test(
      'SSE source takes over lock from DOM watcher and drops subsequent conflicting DOM chunks',
      () async {
        final streamCtrl = StreamController<String>.broadcast();
        addTearDown(streamCtrl.close);

        manager.setTestState(
          status: ChatGptBridgeStatus.generating,
          streamController: streamCtrl,
        );
        manager.setTestRequestId('req_sse_dom_19');

        // 1. Send chunk from DOM -> acquires lock for dom
        manager.handleJsMessageForTest(
          const JavaScriptMessage(
            message:
                '{"type": "chunk", "fullText": "Hello", "source": "dom", "requestId": "req_sse_dom_19"}',
          ),
        );
        expect(manager.lockedSource, equals(BridgeSource.dom));
        expect(manager.accumulator.text, equals('Hello'));

        // 2. Send chunk from SSE -> should takeover lock
        manager.handleJsMessageForTest(
          const JavaScriptMessage(
            message:
                '{"type": "chunk", "fullText": "Hello World", "source": "sse", "requestId": "req_sse_dom_19"}',
          ),
        );
        expect(manager.lockedSource, equals(BridgeSource.sse));
        expect(manager.accumulator.text, equals('Hello World'));

        // Check source_promoted trace entry
        final entries = BridgeTraceLog.instance.entries;
        final promoted = entries.firstWhere((e) => e.type == 'source_promoted');
        expect(promoted.note, contains('promoted_over_dom'));
        expect(promoted.source, equals('sse'));

        // 3. Send another chunk from DOM -> should be rejected because lock is with active SSE
        manager.handleJsMessageForTest(
          const JavaScriptMessage(
            message:
                '{"type": "chunk", "fullText": "Hello World conflicting DOM", "source": "dom", "requestId": "req_sse_dom_19"}',
          ),
        );
        // Text should not have changed from DOM
        expect(manager.accumulator.text, equals('Hello World'));

        final dropped = BridgeTraceLog.instance.entries.where(
          (e) => e.type == 'chunk_dropped',
        );
        expect(dropped.isNotEmpty, isTrue);
        expect(dropped.last.note, contains('locked_to_sse'));
      },
    );
  });
}
