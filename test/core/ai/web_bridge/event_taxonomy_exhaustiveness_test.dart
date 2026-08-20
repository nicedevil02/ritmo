import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';

const Set<String> kAllKnownBridgeEventTypes = {
  'ready',
  'network_conversation_started',
  'http_error',
  'selector_health',
  'done',
  'first_token',
  'vpn_required',
  'cloudflare_challenge',
  'cloudflare_resolved',
  'auto_dismiss',
  'chunk',
  'watcher_tick',
  'error',
  'composer_not_found',
  'prompt_typed',
  'send_clicked',
  'send_fallback_enter',
  'resumed',
  'harvest_result',
  'auth_required',
  'fetch_matched',
  'watcher_steady_done',
  'resume_skipped_duplicate',
};

void main() {
  group('DET-09: Event Taxonomy Exhaustiveness Guard', () {
    test('All notifyFlutter event types extracted from JS script match known taxonomy', () {
      final script = ChatGptJsInjector.setupBridgeScript;
      final regex = RegExp(r"notifyFlutter\('([^']+)'");
      final matches = regex.allMatches(script);

      final extractedTypes = matches.map((m) => m.group(1)!).toSet();
      expect(extractedTypes.isNotEmpty, isTrue);

      // Verify that every extracted JS event type is in the known set
      for (final type in extractedTypes) {
        expect(
          kAllKnownBridgeEventTypes.contains(type),
          isTrue,
          reason: 'Event type "$type" found in JS but missing in kAllKnownBridgeEventTypes',
        );
      }

      // Verify all known types are in fact used in JS
      expect(extractedTypes, equals(kAllKnownBridgeEventTypes));
    });

    test('WebBridgeEvent.parse parses every known event type to a typed non-BridgeUnknownEvent', () {
      for (final type in kAllKnownBridgeEventTypes) {
        final samplePayload = {
          'type': type,
          'source': 'test_source',
          'requestId': 'req_sample_123',
          'message': 'Sample message',
          'error': 'Sample error',
          'fullText': 'Sample full text',
          'delta': 'Sample delta',
          'report': {'composer': 1},
          'matchedSelector': 'button',
          'candidateCount': 1,
          'length': 10,
          'statusCode': 200,
          'url': 'https://chatgpt.com',
          'label': 'sample_label',
          'strategy': 'dom',
        };

        final event = WebBridgeEvent.parse(jsonEncode(samplePayload));
        expect(
          event,
          isNot(isA<BridgeUnknownEvent>()),
          reason: 'Event type "$type" parsed to BridgeUnknownEvent unexpectedly.',
        );
      }
    });
  });
}
