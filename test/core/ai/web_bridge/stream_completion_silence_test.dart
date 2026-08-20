import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';

void main() {
  group('DET-33: Stream Completion Silence Window Standardization', () {
    test('setupBridgeScript checks 1200ms silence window and emits stream_completion_evaluated', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('sawGeneratingSignal && lastLength > 0 && idleMs >= 1200'), isTrue);
      expect(script.contains("notifyFlutter('stream_completion_evaluated'"), isTrue);
      expect(script.contains("reason: 'stop_button_disappeared_and_silence_1200ms'"), isTrue);
    });

    test('WebBridgeEvent parses stream_completion_evaluated correctly', () {
      final event = WebBridgeEvent.parse('''{
        "type": "stream_completion_evaluated",
        "reason": "stop_button_disappeared_and_silence_1200ms",
        "idleMs": 1250,
        "textLength": 450,
        "requestId": "req_silence_33",
        "source": "dom"
      }''');

      expect(event, isA<BridgeStreamCompletionEvaluatedEvent>());
      final evaluatedEvent = event as BridgeStreamCompletionEvaluatedEvent;
      expect(evaluatedEvent.reason, equals('stop_button_disappeared_and_silence_1200ms'));
      expect(evaluatedEvent.idleMs, equals(1250));
      expect(evaluatedEvent.textLength, equals(450));
      expect(evaluatedEvent.requestId, equals('req_silence_33'));
      expect(evaluatedEvent.source, equals('dom'));
    });
  });
}
