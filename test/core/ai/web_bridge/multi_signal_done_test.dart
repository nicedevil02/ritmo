import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WEB-20: Multi-Signal Stream Completion Voting', () {
    test('setupBridgeScript contains evaluateStreamCompletion function', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('function evaluateStreamCompletion'), isTrue);
      expect(script.contains('var isFinished = evaluateStreamCompletion()'), isTrue);
    });

    test('setupBridgeScript checks stop button, streaming class, and active send button', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('stop-button'), isTrue);
      expect(script.contains('result-streaming'), isTrue);
      expect(script.contains('send-button'), isTrue);
      expect(script.contains('!sendButton.disabled'), isTrue);
    });

    test('setupBridgeScript enforces fast completion on send button restoration and idle fallback', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('hasSendButton && idleMs > 400'), isTrue);
      expect(script.contains('idleMs > 2500'), isTrue);
    });
  });
}
