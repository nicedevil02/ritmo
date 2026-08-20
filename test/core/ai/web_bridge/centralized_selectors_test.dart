import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WEB-21: Centralized RITMO_SELECTORS & Safe Querying', () {
    test(
      'setupBridgeScript contains RITMO_SELECTORS table with all core definitions',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(script.contains('var RITMO_SELECTORS = {'), isTrue);
        expect(script.contains('composer:'), isTrue);
        expect(script.contains('sendButton:'), isTrue);
        expect(script.contains('stopButton:'), isTrue);
        expect(script.contains('assistantMessage:'), isTrue);
        expect(script.contains('userMessage:'), isTrue);
        expect(script.contains('streamingIndicator:'), isTrue);
        expect(script.contains('cloudflare:'), isTrue);
        expect(script.contains('sidebarClose:'), isTrue);
      },
    );

    test('setupBridgeScript contains querySafe and queryAllSafe helpers', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('function querySafe('), isTrue);
      expect(script.contains('function queryAllSafe('), isTrue);
    });

    test('key functions query DOM via RITMO_SELECTORS', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('querySafe(RITMO_SELECTORS.composer)'), isTrue);
      expect(script.contains('querySafe(RITMO_SELECTORS.stopButton)'), isTrue);
      expect(script.contains('querySafe(RITMO_SELECTORS.sendButton)'), isTrue);
      expect(script.contains('querySafe(RITMO_SELECTORS.cloudflare)'), isTrue);
    });
  });
}
