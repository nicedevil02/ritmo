import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';

void main() {
  group('DET-25: Smart Send Button Polling & Activation Check', () {
    test('setupBridgeScript contains isButtonEnabled helper checking aria-disabled and disabled', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('function isButtonEnabled(btn)'), isTrue);
      expect(script.contains('btn.getAttribute(\'aria-disabled\') === \'true\''), isTrue);
      expect(script.contains('btn.disabled'), isTrue);
      expect(script.contains('isButtonEnabled(sendBtn)'), isTrue);
    });

    test('setupBridgeScript polls send button at 100ms intervals', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('sendInterval = setInterval('), isTrue);
      expect(script.contains('}, 100);'), isTrue);
    });
  });
}
