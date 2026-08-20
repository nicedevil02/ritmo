import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  group('DET-03: watcher heartbeat trace', () {
    test(
      'WebBridgeEvent.parse maps watcher_tick to BridgeWatcherTickEvent with all fields',
      () {
        final jsonStr = jsonEncode({
          'type': 'watcher_tick',
          'requestId': 'req_tick_1',
          'source': 'dom',
          'textLength': 150,
          'hasStopButton': true,
          'hasStreamingIndicator': false,
          'assistantNodes': 3,
          'turnCount': 5,
          'markdownBodies': 2,
          'idleMs': 350,
          'elapsedMs': 5200,
        });

        final event = WebBridgeEvent.parse(jsonStr);
        expect(event, isA<BridgeWatcherTickEvent>());
        final tick = event as BridgeWatcherTickEvent;
        expect(tick.requestId, equals('req_tick_1'));
        expect(tick.source, equals('dom'));
        expect(tick.textLength, equals(150));
        expect(tick.hasStopButton, isTrue);
        expect(tick.hasStreamingIndicator, isFalse);
        expect(tick.assistantNodes, equals(3));
        expect(tick.turnCount, equals(5));
        expect(tick.markdownBodies, equals(2));
        expect(tick.idleMs, equals(350));
        expect(tick.elapsedMs, equals(5200));
      },
    );

    test(
      'setupBridgeScript emits watcher_tick with all required payload fields',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;
        expect(script, contains("notifyFlutter('watcher_tick',"));
        expect(script, contains('hasStopButton:'));
        expect(script, contains('hasStreamingIndicator:'));
        expect(script, contains('assistantNodes:'));
        expect(script, contains('turnCount:'));
        expect(script, contains('markdownBodies:'));
        expect(script, contains('idleMs:'));
        expect(script, contains('elapsedMs:'));
      },
    );

    test(
      'Processing watcher_tick in manager does not modify bridge status or close stream',
      () {
        final manager = ChatGptWebBridgeManager.instance;
        expect(manager.status, equals(ChatGptBridgeStatus.idle));
        // Dispatch watcher_tick via JSON message simulation
        manager.handleJsMessageForTest(
          JavaScriptMessage(
            message: jsonEncode({
              'type': 'watcher_tick',
              'requestId': 'req_test',
              'source': 'dom',
              'textLength': 0,
              'hasStopButton': false,
              'hasStreamingIndicator': false,
              'assistantNodes': 1,
              'turnCount': 1,
              'markdownBodies': 1,
              'idleMs': 0,
              'elapsedMs': 5000,
            }),
          ),
        );
        // Status remains idle (or unchanged)
        expect(manager.status, equals(ChatGptBridgeStatus.idle));
      },
    );
  });
}
