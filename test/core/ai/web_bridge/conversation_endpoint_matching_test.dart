import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';

void main() {
  group('DET-16: Conversation Endpoint Matching', () {
    bool isConversationEndpointDart(String url) {
      final reg1 = RegExp(
        r'[\/\.-]backend-(?:api|anon)\/(?:conversation|lat\/r|f\/r|synthesize)',
        caseSensitive: false,
      );
      final reg2 = RegExp(
        r'[\/\.-]backend-api\/conversation',
        caseSensitive: false,
      );
      final reg3a = RegExp(r'[\/\.-]conversation', caseSensitive: false);
      final reg3b = RegExp(r'[\/\.-]backend', caseSensitive: false);

      return reg1.hasMatch(url) ||
          reg2.hasMatch(url) ||
          (reg3a.hasMatch(url) && reg3b.hasMatch(url));
    }

    test(
      'isConversationEndpoint matches all valid ChatGPT conversation endpoints',
      () {
        expect(isConversationEndpointDart('/backend-api/conversation'), isTrue);
        expect(
          isConversationEndpointDart('/backend-anon/conversation'),
          isTrue,
        );
        expect(isConversationEndpointDart('/backend-api/lat/r'), isTrue);
        expect(isConversationEndpointDart('/backend-api/f/r'), isTrue);
        expect(isConversationEndpointDart('/backend-api/synthesize'), isTrue);
        expect(
          isConversationEndpointDart(
            'https://chatgpt.com/backend-api/conversation?model=auto',
          ),
          isTrue,
        );
        expect(
          isConversationEndpointDart(
            'https://chatgpt.com/backend-anon/conversation',
          ),
          isTrue,
        );
        expect(
          isConversationEndpointDart('/backend-api/conversation/init'),
          isTrue,
        );

        // Non-conversation endpoints should be false
        expect(isConversationEndpointDart('/backend-api/models'), isFalse);
        expect(isConversationEndpointDart('/backend-api/me'), isFalse);
        expect(isConversationEndpointDart('/api/auth/session'), isFalse);
        expect(
          isConversationEndpointDart('https://chatgpt.com/assets/vendor.js'),
          isFalse,
        );
      },
    );

    test(
      'earlyHookScript and setupBridgeScript contain isConversationEndpoint and fetch_matched',
      () {
        final early = ChatGptJsInjector.earlyHookScript;
        final setup = ChatGptJsInjector.setupBridgeScript;

        expect(early.contains('function isConversationEndpoint(url)'), isTrue);
        expect(setup.contains('function isConversationEndpoint(url)'), isTrue);
        expect(early.contains('fetch_matched'), isTrue);
        expect(setup.contains('fetch_matched'), isTrue);
      },
    );

    test('WebBridgeEvent parses fetch_matched correctly', () {
      final event = WebBridgeEvent.parse('''{
        "type": "fetch_matched",
        "url": "/backend-api/conversation",
        "method": "POST",
        "isStream": true,
        "requestId": "req_fetch_1",
        "source": "fetch_hook"
      }''');

      expect(event, isA<BridgeFetchMatchedEvent>());
      final fetchEvent = event as BridgeFetchMatchedEvent;
      expect(fetchEvent.url, equals('/backend-api/conversation'));
      expect(fetchEvent.method, equals('POST'));
      expect(fetchEvent.isStream, isTrue);
      expect(fetchEvent.requestId, equals('req_fetch_1'));
      expect(fetchEvent.source, equals('fetch_hook'));
    });
  });
}
