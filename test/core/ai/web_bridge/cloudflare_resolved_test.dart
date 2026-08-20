import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  group('DET-07: Cloudflare Resolved Event Handling', () {
    test('WebBridgeEvent.parse maps cloudflare_resolved to BridgeCloudflareResolvedEvent', () {
      final jsonStr = jsonEncode({
        'type': 'cloudflare_resolved',
        'source': 'security',
      });
      final event = WebBridgeEvent.parse(jsonStr);
      expect(event, isA<BridgeCloudflareResolvedEvent>());
      expect(event.source, equals('security'));
    });

    test('Receiving cloudflare_resolved transitions bridge status to ready and clears cloudflareNotifier', () {
      final manager = ChatGptWebBridgeManager.instance;
      // Trigger cloudflare challenge event first
      manager.handleJsMessageForTest(JavaScriptMessage(
        message: jsonEncode({
          'type': 'cloudflare_challenge',
          'source': 'security',
          'reason': 'cf_turnstile',
        }),
      ));

      expect(manager.status, equals(ChatGptBridgeStatus.cloudflareChallenge));
      expect(manager.cloudflareNotifier.value, isTrue);

      // Now receive cloudflare_resolved
      manager.handleJsMessageForTest(JavaScriptMessage(
        message: jsonEncode({
          'type': 'cloudflare_resolved',
          'source': 'security',
        }),
      ));

      expect(manager.status, equals(ChatGptBridgeStatus.ready));
      expect(manager.cloudflareNotifier.value, isFalse);

      manager.resetStateForTest();
    });
  });
}
