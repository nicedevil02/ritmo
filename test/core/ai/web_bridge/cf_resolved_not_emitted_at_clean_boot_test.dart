import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';

void main() {
  group('DET-10: Cloudflare Resolved Clean Boot Guard', () {
    test('JS bridge script defines hadCloudflareChallenge flag', () {
      final script = ChatGptJsInjector.setupBridgeScript;
      expect(script.contains('hadCloudflareChallenge = false;'), isTrue);
    });

    test(
      'JS bridge script only emits cloudflare_resolved if hadCloudflareChallenge was true',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;
        expect(script.contains('else if (hadCloudflareChallenge)'), isTrue);
        expect(script.contains("notifyFlutter('cloudflare_resolved'"), isTrue);
      },
    );
  });
}
