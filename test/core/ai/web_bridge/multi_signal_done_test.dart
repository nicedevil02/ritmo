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

    test('setupBridgeScript checks stop button, streaming class, and active indicators', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('stop-button'), isTrue);
      expect(script.contains('result-streaming'), isTrue);
      expect(script.contains('sawGeneratingSignal'), isTrue);
    });

    test('setupBridgeScript enforces confirmed generating transition and idle fallback', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('sawGeneratingSignal && lastLength > 0 && idleMs > 800'), isTrue);
      expect(script.contains('idleMs > 4000'), isTrue);
    });
  });
}
