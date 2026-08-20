import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WEB-14: Direct SSE Line Parser & Stream Reader', () {
    test(
      'setupBridgeScript contains parseSSELine and readSSEStream functions',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(script.contains('function parseSSELine'), isTrue);
        expect(script.contains('function readSSEStream'), isTrue);
        expect(script.contains('window.__ritmo_parseSSELine'), isTrue);
        expect(script.contains('window.__ritmo_readSSEStream'), isTrue);
      },
    );

    test('setupBridgeScript correctly handles [DONE] terminal sentinel', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains("rawData === '[DONE]'"), isTrue);
      expect(script.contains("source: 'sse'"), isTrue);
    });

    test(
      'setupBridgeScript extracts text parts from standard ChatGPT SSE JSON payloads',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(script.contains('json.message.content.parts'), isTrue);
        expect(script.contains('json.delta.content'), isTrue);
        expect(script.contains('json.v.message.content.parts'), isTrue);
      },
    );
  });
}
