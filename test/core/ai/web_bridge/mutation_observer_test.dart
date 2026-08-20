import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WEB-19: MutationObserver DOM Watching & Resource Optimization', () {
    test(
      'setupBridgeScript initializes MutationObserver for DOM observation',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(script.contains('new MutationObserver'), isTrue);
        expect(script.contains('domObserver.observe(document.body'), isTrue);
      },
    );

    test('setupBridgeScript cleans up MutationObserver via disconnect()', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('stopDomObserver()'), isTrue);
      expect(script.contains('domObserver.disconnect()'), isTrue);
    });

    test('setupBridgeScript throttles fallback polling interval to 350ms', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('}, 350);'), isTrue);
    });
  });
}
