import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  group('DET-08: Unknown Bridge Event Safety Net', () {
    test('Unknown event is parsed as BridgeUnknownEvent with raw payload preserved', () {
      final raw = jsonEncode({
        'type': 'some_futuristic_event',
        'foo': 'bar',
        'source': 'unknown_source',
      });
      final event = WebBridgeEvent.parse(raw);
      expect(event, isA<BridgeUnknownEvent>());
      final unk = event as BridgeUnknownEvent;
      expect(unk.type, equals('some_futuristic_event'));
      expect(unk.rawPayload, isA<Map<String, dynamic>>());
      final dynamic map = unk.rawPayload;
      expect(map['foo'], equals('bar'));
    });

    test('Handling unknown event logs to BridgeTraceLog with error level and raw payload', () {
      BridgeTraceLog.instance.clear();
      final manager = ChatGptWebBridgeManager.instance;

      const rawJson = '{"type":"unrecognized_xyz_event","payload":{"x":123}}';
      manager.handleJsMessageForTest(const JavaScriptMessage(message: rawJson));

      final entries = BridgeTraceLog.instance.entries;
      expect(entries.isNotEmpty, isTrue);
      final lastEntry = entries.last;
      expect(lastEntry.type, equals('unknown_event'));
      expect(lastEntry.level, equals(BridgeTraceLevel.error));
      expect(lastEntry.note, contains('type=unrecognized_xyz_event'));
      expect(lastEntry.note, contains('unrecognized_xyz_event'));
    });
  });
}
