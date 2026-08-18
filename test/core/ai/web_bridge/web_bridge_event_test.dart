import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';

void main() {
  group('A-02: WebBridgeEvent.parse', () {
    test('parses ready event', () {
      const json = '{"type": "ready", "source": "dom", "payload": {"isAuthed": true, "email": "user@example.com", "version": 8}}';
      final event = WebBridgeEvent.parse(json);
      expect(event, isA<BridgeReadyEvent>());
      final ready = event as BridgeReadyEvent;
      expect(ready.isAuthed, isTrue);
      expect(ready.email, equals('user@example.com'));
      expect(ready.version, equals(8));
      expect(ready.source, equals('dom'));
    });

    test('parses chunk event', () {
      const json = '{"type": "chunk", "source": "sse", "payload": {"delta": "سلام", "fullText": "سلام", "requestId": "req_1"}}';
      final event = WebBridgeEvent.parse(json);
      expect(event, isA<BridgeChunkEvent>());
      final chunk = event as BridgeChunkEvent;
      expect(chunk.delta, equals('سلام'));
      expect(chunk.fullText, equals('سلام'));
      expect(chunk.requestId, equals('req_1'));
      expect(chunk.source, equals('sse'));
    });

    test('parses done event', () {
      const json = '{"type": "done", "source": "dom", "payload": {"fullText": "پاسخ نهایی", "requestId": "req_2"}}';
      final event = WebBridgeEvent.parse(json);
      expect(event, isA<BridgeDoneEvent>());
      final done = event as BridgeDoneEvent;
      expect(done.fullText, equals('پاسخ نهایی'));
      expect(done.requestId, equals('req_2'));
    });

    test('parses first_token event', () {
      const json = '{"type": "first_token", "source": "dom", "payload": {"requestId": "req_3"}}';
      final event = WebBridgeEvent.parse(json);
      expect(event, isA<BridgeFirstTokenEvent>());
      final ft = event as BridgeFirstTokenEvent;
      expect(ft.requestId, equals('req_3'));
    });

    test('parses resumed event', () {
      const json = '{"type": "resumed", "source": "dom", "payload": {"stage": "streaming", "requestId": "req_4", "recoveredLength": 150}}';
      final event = WebBridgeEvent.parse(json);
      expect(event, isA<BridgeResumedEvent>());
      final resumed = event as BridgeResumedEvent;
      expect(resumed.stage, equals('streaming'));
      expect(resumed.requestId, equals('req_4'));
      expect(resumed.recoveredLength, equals(150));
    });

    test('parses http_error event', () {
      const json = '{"type": "http_error", "source": "fetch", "payload": {"statusCode": 429, "message": "Rate limit reached", "requestId": "req_5"}}';
      final event = WebBridgeEvent.parse(json);
      expect(event, isA<BridgeHttpErrorEvent>());
      final err = event as BridgeHttpErrorEvent;
      expect(err.statusCode, equals(429));
      expect(err.message, equals('Rate limit reached'));
    });

    test('parses auth_required event', () {
      const json = '{"type": "auth_required", "source": "lifecycle", "payload": {"url": "https://chatgpt.com/auth/login", "isLoginModal": true, "isExpired": true}}';
      final event = WebBridgeEvent.parse(json);
      expect(event, isA<BridgeAuthRequiredEvent>());
      final auth = event as BridgeAuthRequiredEvent;
      expect(auth.url, equals('https://chatgpt.com/auth/login'));
      expect(auth.isLoginModal, isTrue);
      expect(auth.isExpired, isTrue);
    });

    test('parses cloudflare_challenge event', () {
      const json = '{"type": "cloudflare_challenge", "source": "lifecycle", "payload": {"reason": "Turnstile challenge required"}}';
      final event = WebBridgeEvent.parse(json);
      expect(event, isA<BridgeCloudflareEvent>());
      final cf = event as BridgeCloudflareEvent;
      expect(cf.reason, equals('Turnstile challenge required'));
    });

    test('parses selector_health event', () {
      const json = '{"type": "selector_health", "source": "lifecycle", "payload": {"issue": "no_generating_signal_observed", "bridgeVersion": 8, "report": {"composer": 1, "sendButton": 1}}}';
      final event = WebBridgeEvent.parse(json);
      expect(event, isA<BridgeSelectorHealthEvent>());
      final sh = event as BridgeSelectorHealthEvent;
      expect(sh.issue, equals('no_generating_signal_observed'));
      expect(sh.bridgeVersion, equals(8));
      expect(sh.report?['composer'], equals(1));
    });

    test('parses auto_dismiss event', () {
      const json = '{"type": "auto_dismiss", "source": "lifecycle", "payload": {"label": "Accept cookies"}}';
      final event = WebBridgeEvent.parse(json);
      expect(event, isA<BridgeAutoDismissEvent>());
      final ad = event as BridgeAutoDismissEvent;
      expect(ad.label, equals('Accept cookies'));
    });

    test('parses harvest_result event', () {
      const json = '{"type": "harvest_result", "source": "dom", "payload": {"fullText": "متن برداشت‌شده دستی", "requestId": "req_6", "strategy": "manual"}}';
      final event = WebBridgeEvent.parse(json);
      expect(event, isA<BridgeHarvestResultEvent>());
      final hr = event as BridgeHarvestResultEvent;
      expect(hr.fullText, equals('متن برداشت‌شده دستی'));
      expect(hr.requestId, equals('req_6'));
      expect(hr.strategy, equals('manual'));
    });

    test('handles unknown event types gracefully', () {
      const json = '{"type": "custom_future_event", "source": "dom", "payload": {"foo": "bar"}}';
      final event = WebBridgeEvent.parse(json);
      expect(event, isA<BridgeUnknownEvent>());
      final unk = event as BridgeUnknownEvent;
      expect(unk.type, equals('custom_future_event'));
    });

    test('handles malformed JSON without crashing', () {
      const json = 'MALFORMED_JSON_STRING{';
      final event = WebBridgeEvent.parse(json);
      expect(event, isA<BridgeUnknownEvent>());
      final unk = event as BridgeUnknownEvent;
      expect(unk.type, equals('parse_error'));
      expect(unk.error, isNotNull);
    });

    test('parseBridgeSource maps strings to BridgeSource correctly', () {
      expect(parseBridgeSource('sse'), equals(BridgeSource.sse));
      expect(parseBridgeSource('dom'), equals(BridgeSource.dom));
      expect(parseBridgeSource('fetch'), equals(BridgeSource.fetch));
      expect(parseBridgeSource('lifecycle'), equals(BridgeSource.lifecycle));
      expect(parseBridgeSource('other'), equals(BridgeSource.dart));
    });
  });
}
