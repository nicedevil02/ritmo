import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';

void main() {
  group('DET-05: Bridge Version Bump to 9', () {
    test('ChatGptWebBridgeManager.requiredBridgeVersion and bridgeVersion are 9', () {
      expect(ChatGptWebBridgeManager.requiredBridgeVersion, equals(9));
      expect(ChatGptWebBridgeManager.instance.bridgeVersion, equals(9));
      expect(ChatGptJsInjector.bridgeVersion, equals(9));
    });

    test('setupBridgeScript contains requiredVersion = 9 and window.__RITMO_BRIDGE_V', () {
      final script = ChatGptJsInjector.setupBridgeScript;
      expect(script, contains('var requiredVersion = 9;'));
      expect(script, contains('window.__RITMO_BRIDGE_V'));
    });
  });
}
