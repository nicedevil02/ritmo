import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_exception.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatGptWebBridgeManager manager;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
  });

  tearDown(() {
    manager.disposeWebView();
  });

  group('WEB-25: Typed WebBridgeException Architecture', () {
    test(
      'all factory constructors produce appropriate kind, message, and action text',
      () {
        final auth = WebBridgeException.authRequired();
        expect(auth.kind, equals(WebBridgeErrorKind.authRequired));
        expect(auth.messageFa.contains('وارد حساب کاربری'), isTrue);
        expect(auth.actionTextFa, equals('ورود به حساب کاربری'));

        final cf = WebBridgeException.cloudflareChallenge();
        expect(cf.kind, equals(WebBridgeErrorKind.cloudflareChallenge));
        expect(cf.actionTextFa, equals('تکمیل تایید امنیتی'));

        final rate = WebBridgeException.rateLimited();
        expect(rate.kind, equals(WebBridgeErrorKind.rateLimited));
        expect(rate.statusCode, equals(429));

        final server = WebBridgeException.serverError(statusCode: 502);
        expect(server.kind, equals(WebBridgeErrorKind.serverError));
        expect(server.statusCode, equals(502));

        final timeout = WebBridgeException.timeout();
        expect(timeout.kind, equals(WebBridgeErrorKind.timeout));

        final net = WebBridgeException.networkError();
        expect(net.kind, equals(WebBridgeErrorKind.networkError));

        final composer = WebBridgeException.composerNotFound();
        expect(composer.kind, equals(WebBridgeErrorKind.composerNotFound));

        final nav = WebBridgeException.navigationLoop();
        expect(nav.kind, equals(WebBridgeErrorKind.navigationLoop));
      },
    );

    test(
      'manager emits WebBridgeException on http_error 429 to stream controller',
      () async {
        final streamController = StreamController<String>();
        addTearDown(streamController.close);
        manager.setTestState(
          status: ChatGptBridgeStatus.generating,
          streamController: streamController,
        );
        manager.setTestRequestId('req_err_1');

        Object? receivedError;
        streamController.stream.listen(
          (_) {},
          onError: (err) {
            receivedError = err;
          },
        );

        final msg = JavaScriptMessage(
          message: jsonEncode({
            'type': 'http_error',
            'statusCode': 429,
            'requestId': 'req_err_1',
          }),
        );

        manager.handleJsMessageForTest(msg);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(receivedError, isA<WebBridgeException>());
        final webEx = receivedError as WebBridgeException;
        expect(webEx.kind, equals(WebBridgeErrorKind.rateLimited));
        expect(webEx.statusCode, equals(429));
      },
    );
  });
}
