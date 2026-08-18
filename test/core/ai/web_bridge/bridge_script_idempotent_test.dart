import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';

void main() {
  group('WEB-03: Versioned Idempotent Bridge Script Guard', () {
    test('bridgeVersion constant is defined as 7', () {
      expect(ChatGptJsInjector.bridgeVersion, equals(7));
    });

    test('setupBridgeScript contains version identifier and matches bridgeVersion', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('window.__RITMO_BRIDGE_V'), isTrue);
      expect(script.contains('var requiredVersion = ${ChatGptJsInjector.bridgeVersion};'), isTrue);
      expect(script.contains('__RITMO_BRIDGE_INITIALIZED__'), isFalse,
          reason: 'Legacy unversioned boolean guard should be completely removed');
    });

    test('setupBridgeScript posts ready event on warm document branch', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('isWarm: true'), isTrue);
      expect(script.contains('currentVersion === requiredVersion'), isTrue);
      expect(script.contains('hasComposer: checkComposerPresent()'), isTrue);
      expect(script.contains('currentPath: window.location.pathname'), isTrue);
    });

    test('setupBridgeScript defines __ritmo_cleanup for idempotent re-injection', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('window.__ritmo_cleanup'), isTrue);
    });
  });
}
