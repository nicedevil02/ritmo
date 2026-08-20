import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  group('DET-11: Ready Event Warm Flag and Properties', () {
    test('WebBridgeEvent.parse parses isWarm, currentPath, and hasComposer', () {
      final jsonStr = jsonEncode({
        'type': 'ready',
        'version': 9,
        'isWarm': true,
        'currentPath': '/c/abcd-1234',
        'hasComposer': true,
        'isAuthed': true,
        'source': 'lifecycle',
      });
      final event = WebBridgeEvent.parse(jsonStr);
      expect(event, isA<BridgeReadyEvent>());
      final ready = event as BridgeReadyEvent;
      expect(ready.isWarm, isTrue);
      expect(ready.currentPath, equals('/c/abcd-1234'));
      expect(ready.hasComposer, isTrue);
      expect(ready.version, equals(9));
      expect(ready.isAuthed, isTrue);
    });

    test('Default isWarm is false when omitted in payload', () {
      final jsonStr = jsonEncode({
        'type': 'ready',
        'version': 9,
        'source': 'lifecycle',
      });
      final event = WebBridgeEvent.parse(jsonStr);
      expect(event, isA<BridgeReadyEvent>());
      final ready = event as BridgeReadyEvent;
      expect(ready.isWarm, isFalse);
    });

    test('Handling ready event records warm flag and path in BridgeTraceLog', () {
      BridgeTraceLog.instance.clear();
      final manager = ChatGptWebBridgeManager.instance;

      final msg = JavaScriptMessage(
        message: jsonEncode({
          'type': 'ready',
          'version': 9,
          'isWarm': true,
          'currentPath': '/c/chat-session-567',
          'hasComposer': true,
          'isAuthed': true,
          'source': 'lifecycle',
        }),
      );

      manager.handleJsMessageForTest(msg);

      final entries = BridgeTraceLog.instance.entries;
      expect(entries.isNotEmpty, isTrue);
      final lastEntry = entries.last;
      expect(lastEntry.type, equals('ready'));
      expect(lastEntry.note, contains('warm=true'));
      expect(lastEntry.note, contains('path=/c/chat-session-567'));
      expect(lastEntry.note, contains('composer=true'));

      manager.resetStateForTest();
    });
  });
}
