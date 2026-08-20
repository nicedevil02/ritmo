import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';

void main() {
  group('DET-04: selector_health phases in critical moments', () {
    test('WebBridgeEvent.parse correctly parses phase and requestId on BridgeSelectorHealthEvent', () {
      final jsonStr = jsonEncode({
        'type': 'selector_health',
        'phase': 'pre_send',
        'requestId': 'req_sel_1',
        'source': 'lifecycle',
        'bridgeVersion': 9,
        'report': {
          'composer': 1,
          'sendButton': 1,
          'stopButton': 0,
        },
      });

      final event = WebBridgeEvent.parse(jsonStr);
      expect(event, isA<BridgeSelectorHealthEvent>());
      final health = event as BridgeSelectorHealthEvent;
      expect(health.phase, equals('pre_send'));
      expect(health.requestId, equals('req_sel_1'));
      expect(health.source, equals('lifecycle'));
      expect(health.bridgeVersion, equals(9));
      expect(health.report, isNotNull);
      expect(health.report!['composer'], equals(1));
    });

    test('setupBridgeScript contains selector_health self tests for boot, pre_send, post_first_text, pre_timeout', () {
      final script = ChatGptJsInjector.setupBridgeScript;
      expect(script, contains("phase: 'boot'"));
      expect(script, contains("phase: 'pre_send'"));
      expect(script, contains("phase: 'post_first_text'"));
      expect(script, contains("phase: 'pre_timeout'"));
    });
  });
}
