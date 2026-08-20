import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';

void main() {
  group('A-52: Centralized Selector Contract and Safe DOM Access', () {
    test(
      'setupBridgeScript contains RITMO_SELECTORS map with all required DOM elements',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(script.contains('RITMO_SELECTORS'), isTrue);
        expect(script.contains('composer:'), isTrue);
        expect(script.contains('sendButton:'), isTrue);
        expect(script.contains('stopButton:'), isTrue);
        expect(script.contains('assistantMessage:'), isTrue);
        expect(script.contains('streamingIndicator:'), isTrue);
        expect(script.contains('conversationTurns:'), isTrue);
        expect(script.contains('userMessage:'), isTrue);
        expect(script.contains('markdownBodies:'), isTrue);
      },
    );

    test(
      'setupBridgeScript defines safe querying utilities querySafe and queryAllSafe',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(script.contains('function querySafe('), isTrue);
        expect(script.contains('function queryAllSafe('), isTrue);
      },
    );

    test(
      'setupBridgeScript runs selector self-test and emits selector_health event',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(script.contains('runSelectorSelfTest'), isTrue);
        expect(script.contains('selector_health'), isTrue);
      },
    );
  });
}
