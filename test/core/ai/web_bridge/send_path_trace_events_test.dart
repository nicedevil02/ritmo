import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';

void main() {
  group('DET-02: send-path trace events', () {
    test(
      'WebBridgeEvent.parse correctly parses all 4 send-path trace events',
      () {
        final promptTypedJson = jsonEncode({
          'type': 'prompt_typed',
          'length': 42,
          'requestId': 'req_123',
          'source': 'dom',
        });
        final promptTypedEvt = WebBridgeEvent.parse(promptTypedJson);
        expect(promptTypedEvt, isA<BridgePromptTypedEvent>());
        final typedTyped = promptTypedEvt as BridgePromptTypedEvent;
        expect(typedTyped.length, equals(42));
        expect(typedTyped.requestId, equals('req_123'));
        expect(typedTyped.source, equals('dom'));

        final sendClickedJson = jsonEncode({
          'type': 'send_clicked',
          'requestId': 'req_123',
          'matchedSelector': 'button[data-testid="send-button"]',
          'candidateCount': 2,
          'source': 'dom',
        });
        final sendClickedEvt = WebBridgeEvent.parse(sendClickedJson);
        expect(sendClickedEvt, isA<BridgeSendClickedEvent>());
        final typedClicked = sendClickedEvt as BridgeSendClickedEvent;
        expect(typedClicked.requestId, equals('req_123'));
        expect(
          typedClicked.matchedSelector,
          equals('button[data-testid="send-button"]'),
        );
        expect(typedClicked.candidateCount, equals(2));

        final sendFallbackJson = jsonEncode({
          'type': 'send_fallback_enter',
          'requestId': 'req_123',
          'source': 'dom',
        });
        final sendFallbackEvt = WebBridgeEvent.parse(sendFallbackJson);
        expect(sendFallbackEvt, isA<BridgeSendFallbackEnterEvent>());
        final typedFallback = sendFallbackEvt as BridgeSendFallbackEnterEvent;
        expect(typedFallback.requestId, equals('req_123'));

        final composerNotFoundJson = jsonEncode({
          'type': 'composer_not_found',
          'requestId': 'req_123',
          'source': 'dom',
        });
        final composerNotFoundEvt = WebBridgeEvent.parse(composerNotFoundJson);
        expect(composerNotFoundEvt, isA<BridgeComposerNotFoundEvent>());
        final typedNotFound =
            composerNotFoundEvt as BridgeComposerNotFoundEvent;
        expect(typedNotFound.requestId, equals('req_123'));
      },
    );

    test(
      'setupBridgeScript contains notifyFlutter calls for send-path events',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;
        expect(script, contains("notifyFlutter('prompt_typed',"));
        expect(script, contains("notifyFlutter('send_clicked',"));
        expect(script, contains("notifyFlutter('send_fallback_enter',"));
        expect(script, contains("notifyFlutter('composer_not_found',"));
      },
    );
  });
}
