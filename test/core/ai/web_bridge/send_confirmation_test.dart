import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';

void main() {
  group('DET-26: Prompt Submission Verification and Retry', () {
    test(
      'setupBridgeScript contains verifySubmissionAndRetry and send_retry_triggered',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(
          script.contains('function verifySubmissionAndRetry(isEnter)'),
          isTrue,
        );
        expect(script.contains("notifyFlutter('send_retry_triggered'"), isTrue);
        expect(script.contains('verifySubmissionAndRetry(false)'), isTrue);
        expect(script.contains('verifySubmissionAndRetry(true)'), isTrue);
      },
    );

    test('WebBridgeEvent parses send_retry_triggered correctly', () {
      final event = WebBridgeEvent.parse('''{
        "type": "send_retry_triggered",
        "requestId": "req_retry_26",
        "source": "dom"
      }''');

      expect(event, isA<BridgeSendRetryTriggeredEvent>());
      final retryEvent = event as BridgeSendRetryTriggeredEvent;
      expect(retryEvent.requestId, equals('req_retry_26'));
      expect(retryEvent.source, equals('dom'));
    });
  });
}
