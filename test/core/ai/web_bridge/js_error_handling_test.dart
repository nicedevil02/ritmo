import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_exception.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  group('DET-06: JS Error Event Handling', () {
    test('WebBridgeEvent.parse maps error to BridgeErrorEvent', () {
      final jsonStr = jsonEncode({
        'type': 'error',
        'message': 'فیلد ورودی متن ChatGPT هنوز لود نشده است.',
        'requestId': 'req_err_1',
        'source': 'dom',
      });
      final event = WebBridgeEvent.parse(jsonStr);
      expect(event, isA<BridgeErrorEvent>());
      final err = event as BridgeErrorEvent;
      expect(err.message, equals('فیلد ورودی متن ChatGPT هنوز لود نشده است.'));
      expect(err.requestId, equals('req_err_1'));
      expect(err.source, equals('dom'));
    });

    test('Receiving error event while generating fails the stream with WebBridgeException', () async {
      final manager = ChatGptWebBridgeManager.instance;
      final streamController = StreamController<String>();
      addTearDown(streamController.close);

      manager.setTestState(
        status: ChatGptBridgeStatus.generating,
        streamController: streamController,
      );
      manager.setTestRequestId('req_err_test');

      final errors = <dynamic>[];
      final completer = Completer<void>();

      final sub = streamController.stream.listen(
        (_) {},
        onError: (err) {
          errors.add(err);
          if (!completer.isCompleted) completer.complete();
        },
      );

      manager.handleJsMessageForTest(JavaScriptMessage(
        message: jsonEncode({
          'type': 'error',
          'message': 'فیلد ورودی متن ChatGPT هنوز لود نشده است.',
          'requestId': 'req_err_test',
          'source': 'dom',
        }),
      ));

      await completer.future.timeout(const Duration(seconds: 1));
      expect(errors.isNotEmpty, isTrue);
      expect(errors.first, isA<WebBridgeException>());
      final webEx = errors.first as WebBridgeException;
      expect(webEx.messageFa, contains('فیلد ورودی متن ChatGPT'));
      expect(manager.status, equals(ChatGptBridgeStatus.ready));

      await sub.cancel();
      manager.resetStateForTest();
    });
  });
}
