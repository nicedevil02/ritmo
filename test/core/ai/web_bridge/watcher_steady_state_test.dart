import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';

void main() {
  group('DET-20: 2s Steady State in Watcher', () {
    test('setupBridgeScript contains 2s steady state logic and watcher_steady_done event', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('idleMs >= 2000'), isTrue);
      expect(script.contains("notifyFlutter('watcher_steady_done'"), isTrue);
      expect(script.contains('textLength: lastLength'), isTrue);
      expect(script.contains('source: \'dom\''), isTrue);
    });

    test('WebBridgeEvent parses watcher_steady_done correctly', () {
      final event = WebBridgeEvent.parse('''{
        "type": "watcher_steady_done",
        "textLength": 250,
        "idleMs": 2100,
        "requestId": "req_steady_20",
        "source": "dom"
      }''');

      expect(event, isA<BridgeWatcherSteadyDoneEvent>());
      final steadyEvent = event as BridgeWatcherSteadyDoneEvent;
      expect(steadyEvent.textLength, equals(250));
      expect(steadyEvent.idleMs, equals(2100));
      expect(steadyEvent.requestId, equals('req_steady_20'));
      expect(steadyEvent.source, equals('dom'));
    });
  });
}
