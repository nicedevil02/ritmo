import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_exception.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  late ChatGptWebBridgeManager manager;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
    BridgeTraceLog.instance.clear();
  });

  tearDown(() {
    manager.resetStateForTest();
  });

  group('DET-31: Fast Fail on Server HTTP Errors', () {
    test(
      'BridgeHttpErrorEvent with 500 immediately fails generation with serverError',
      () async {
        final streamCtrl = StreamController<String>.broadcast();
        addTearDown(streamCtrl.close);

        manager.setTestState(
          status: ChatGptBridgeStatus.generating,
          streamController: streamCtrl,
        );
        manager.setTestRequestId('req_http_500');

        Object? capturedError;
        streamCtrl.stream.listen(
          (_) {},
          onError: (err) {
            capturedError = err;
          },
        );

        manager.handleJsMessageForTest(
          const JavaScriptMessage(
            message: '''{
        "type": "http_error",
        "statusCode": 500,
        "message": "Internal Server Error",
        "requestId": "req_http_500",
        "source": "fetch"
      }''',
          ),
        );

        await Future.delayed(Duration.zero);

        expect(capturedError, isA<WebBridgeException>());
        final exc = capturedError as WebBridgeException;
        expect(exc.kind, equals(WebBridgeErrorKind.serverError));
        expect(exc.statusCode, equals(500));
        expect(streamCtrl.isClosed, isTrue);
      },
    );

    test(
      'BridgeHttpErrorEvent with 429 immediately fails generation with rateLimited',
      () async {
        final streamCtrl = StreamController<String>.broadcast();
        addTearDown(streamCtrl.close);

        manager.setTestState(
          status: ChatGptBridgeStatus.generating,
          streamController: streamCtrl,
        );
        manager.setTestRequestId('req_http_429');

        Object? capturedError;
        streamCtrl.stream.listen(
          (_) {},
          onError: (err) {
            capturedError = err;
          },
        );

        manager.handleJsMessageForTest(
          const JavaScriptMessage(
            message: '''{
        "type": "http_error",
        "statusCode": 429,
        "message": "Too Many Requests",
        "requestId": "req_http_429",
        "source": "fetch"
      }''',
          ),
        );

        await Future.delayed(Duration.zero);

        expect(capturedError, isA<WebBridgeException>());
        final exc = capturedError as WebBridgeException;
        expect(exc.kind, equals(WebBridgeErrorKind.rateLimited));
        expect(exc.statusCode, equals(429));
        expect(streamCtrl.isClosed, isTrue);
      },
    );
  });
}
