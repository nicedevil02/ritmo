import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';

void main() {
  group('DET-28: Guest Session Detection', () {
    test(
      'setupBridgeScript contains guest session detection and guest_session_detected event',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(
          script.contains("notifyFlutter('guest_session_detected'"),
          isTrue,
        );
        expect(script.contains('isGuest: true'), isTrue);
        expect(script.contains('hasGuestBanner'), isTrue);
      },
    );

    test('WebBridgeEvent parses guest_session_detected correctly', () {
      final event = WebBridgeEvent.parse('''{
        "type": "guest_session_detected",
        "hasComposer": true,
        "hasLoginButton": true,
        "currentPath": "/",
        "isGuest": true,
        "source": "lifecycle"
      }''');

      expect(event, isA<BridgeGuestSessionDetectedEvent>());
      final guestEvent = event as BridgeGuestSessionDetectedEvent;
      expect(guestEvent.hasComposer, isTrue);
      expect(guestEvent.hasLoginButton, isTrue);
      expect(guestEvent.currentPath, equals('/'));
      expect(guestEvent.isGuest, isTrue);
      expect(guestEvent.source, equals('lifecycle'));
    });
  });
}
