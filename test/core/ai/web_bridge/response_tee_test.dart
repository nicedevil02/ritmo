import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WEB-15: Response Body Tee Stream Forking', () {
    test('setupBridgeScript forks response body via response.body.tee()', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('response.body.tee()'), isTrue);
      expect(script.contains('branches[0].getReader()'), isTrue);
      expect(
        script.contains('readSSEStream(ritmoReader, activeReqId)'),
        isTrue,
      );
    });

    test(
      'setupBridgeScript clones response for ChatGPT UI via new Response(branches[1])',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(script.contains('new Response(branches[1]'), isTrue);
        expect(script.contains('headers: response.headers'), isTrue);
        expect(script.contains('status: response.status'), isTrue);
      },
    );

    test(
      'setupBridgeScript includes safety fallback to original response if tee fails',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(
          script.contains(
            'response.body.tee failed, falling back to original response',
          ),
          isTrue,
        );
      },
    );
  });
}
