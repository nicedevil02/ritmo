import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_bridge_timeouts.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_exception.dart';
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

  group('DET-36: Full Regression Suite for Web Bridge Detection Fixes', () {
    test('1. Protocol version and timeouts configuration', () {
      expect(ChatGptJsInjector.bridgeVersion, equals(9));
      expect(ChatGptWebBridgeManager.requiredBridgeVersion, equals(9));
      expect(ChatGptWebBridgeManager.enableWebBridgeStreaming, isTrue);
      expect(ChatGptBridgeTimeouts.checkpoint3Delay, equals(const Duration(seconds: 90)));
    });

    test('2. Complete taxonomy of bridge events parse cleanly', () {
      final jsonSamples = [
        '{"type":"ready","version":9,"isWarm":true,"currentPath":"/","hasComposer":true,"source":"lifecycle"}',
        '{"type":"prompt_typed","length":15,"requestId":"r1","source":"dom"}',
        '{"type":"send_clicked","matchedSelector":"btn","candidateCount":1,"requestId":"r1","source":"dom"}',
        '{"type":"send_fallback_enter","requestId":"r1","source":"dom"}',
        '{"type":"send_retry_triggered","requestId":"r1","source":"dom"}',
        '{"type":"first_token","length":5,"latencyMs":350,"requestId":"r1","source":"dom"}',
        '{"type":"chunk","delta":"test","requestId":"r1","source":"dom"}',
        '{"type":"watcher_tick","textLength":10,"hasStopButton":true,"hasStreamingIndicator":false,"assistantNodes":1,"turnCount":1,"markdownBodies":1,"idleMs":200,"elapsedMs":5000,"requestId":"r1","source":"dom"}',
        '{"type":"watcher_steady_done","textLength":100,"idleMs":2000,"requestId":"r1","source":"dom"}',
        '{"type":"stream_completion_evaluated","reason":"silence","idleMs":1200,"textLength":100,"requestId":"r1","source":"dom"}',
        '{"type":"guest_session_detected","hasComposer":true,"hasLoginButton":true,"currentPath":"/","isGuest":true,"source":"lifecycle"}',
        '{"type":"cloudflare_resolved","source":"lifecycle"}',
        '{"type":"resume_skipped_duplicate","requestId":"r1","source":"dom"}',
        '{"type":"fetch_matched","url":"/backend-api/conversation","method":"POST","isStream":true,"requestId":"r1","source":"fetch"}',
        '{"type":"selector_health","report":{"ok":true},"bridgeVersion":9,"phase":"boot","source":"lifecycle"}',
      ];

      for (final json in jsonSamples) {
        final ev = WebBridgeEvent.parse(json);
        expect(ev, isNot(isA<BridgeUnknownEvent>()), reason: 'Failed parsing: ');
        expect(ev.source, isNotEmpty);
      }
    });

    test('3. Bridge ready event never downgrades generating status', () async {
      final streamCtrl = StreamController<String>.broadcast();
      addTearDown(streamCtrl.close);

      manager.setTestState(
        status: ChatGptBridgeStatus.generating,
        streamController: streamCtrl,
      );
      manager.setTestRequestId('req_generating_active');

      manager.handleJsMessageForTest(const JavaScriptMessage(
        message: '{"type":"ready","version":9,"isWarm":true,"currentPath":"/","hasComposer":true,"source":"lifecycle"}',
      ));

      expect(manager.statusNotifier.value, equals(ChatGptBridgeStatus.generating));
    });

    test('4. SSE streaming locks source and promotes over DOM', () async {
      final streamCtrl = StreamController<String>.broadcast();
      addTearDown(streamCtrl.close);

      manager.setTestState(
        status: ChatGptBridgeStatus.generating,
        streamController: streamCtrl,
      );
      manager.setTestRequestId('req_sse_test');

      // DOM chunk first
      manager.handleJsMessageForTest(const JavaScriptMessage(
        message: '{"type":"chunk","delta":"DOM Chunk","source":"dom"}',
      ));

      // SSE chunk arrives -> promotes over DOM
      manager.handleJsMessageForTest(const JavaScriptMessage(
        message: '{"type":"chunk","delta":"DOM Chunk + SSE Next","source":"sse"}',
      ));

      // Subsequent DOM chunk is dropped while SSE is active
      manager.handleJsMessageForTest(const JavaScriptMessage(
        message: '{"type":"chunk","delta":"Late DOM","source":"dom"}',
      ));

      final entries = BridgeTraceLog.instance.entries;
      expect(entries.any((e) => e.type == 'source_promoted'), isTrue);
    });

    test('5. Fast fail on server error cancels generation cleanly', () async {
      final streamCtrl = StreamController<String>.broadcast();
      addTearDown(streamCtrl.close);

      manager.setTestState(
        status: ChatGptBridgeStatus.generating,
        streamController: streamCtrl,
      );
      manager.setTestRequestId('req_fail_fast');

      manager.handleJsMessageForTest(const JavaScriptMessage(
        message: '{"type":"http_error","statusCode":503,"message":"Service Unavailable","source":"fetch"}',
      ));

      await Future.delayed(Duration.zero);

      expect(manager.statusNotifier.value, equals(ChatGptBridgeStatus.ready));
      expect(streamCtrl.isClosed, isTrue);
    });
  });
}
