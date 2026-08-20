import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';

void main() {
  group('DET-01: notifyFlutter always attaches source to event payloads', () {
    test(
      'setupBridgeScript and earlyHookScript guarantee source property on notifyFlutter',
      () {
        final setupScript = ChatGptJsInjector.setupBridgeScript;
        final earlyScript = ChatGptJsInjector.earlyHookScript;

        // 1. Check notifyFlutter definition has default source: 'lifecycle'
        expect(
          setupScript,
          contains("data.source = 'lifecycle';"),
          reason:
              'notifyFlutter must automatically assign lifecycle source if omitted',
        );

        // 2. Check earlyHookScript posts have explicit source fields
        expect(
          earlyScript,
          contains("source: 'fetch'"),
          reason: 'earlyHookScript conversation events must have source: fetch',
        );

        // 3. Count notifyFlutter occurrences in setupBridgeScript
        final notifyPattern = RegExp(r'notifyFlutter\(');
        final notifyMatches = notifyPattern.allMatches(setupScript);
        expect(notifyMatches.isNotEmpty, isTrue);

        // 4. Verify explicit source in ready and vpn/cf events
        expect(setupScript, contains("notifyFlutter('ready',"));
        expect(setupScript, contains("source: 'lifecycle'"));
        expect(setupScript, contains("source: 'dom'"));
        expect(setupScript, contains("source: 'harvest'"));
      },
    );
  });
}
