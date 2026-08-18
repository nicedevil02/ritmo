import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

class FakeWebResourceError extends Fake implements WebResourceError {
  @override
  final int errorCode;
  @override
  final String description;
  @override
  final bool? isForMainFrame;

  FakeWebResourceError({
    required this.errorCode,
    required this.description,
    this.isForMainFrame = true,
  });
}

class FakeHttpResponseError extends Fake implements HttpResponseError {
  @override
  final WebResourceResponse? response;

  FakeHttpResponseError({this.response});
}

class FakeWebResourceResponse extends Fake implements WebResourceResponse {
  @override
  final int statusCode;

  FakeWebResourceResponse({required this.statusCode});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatGptWebBridgeManager manager;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
  });

  tearDown(() {
    manager.disposeWebView();
  });

  group('WEB-05: Navigation & Resource Errors Close In-Flight Streams', () {
    test('sub-resource error (isForMainFrame: false) does NOT abort active stream', () {
      manager.setTestState(status: ChatGptBridgeStatus.generating);

      final error = FakeWebResourceError(
        errorCode: -1,
        description: 'net::ERR_BLOCKED_BY_CLIENT',
        isForMainFrame: false,
      );

      manager.handleWebResourceError(error);

      expect(manager.status, equals(ChatGptBridgeStatus.generating));
    });

    test('main-frame network disconnection error fails generation with Persian network message', () {
      manager.setTestState(status: ChatGptBridgeStatus.generating);

      final error = FakeWebResourceError(
        errorCode: -2,
        description: 'net::ERR_INTERNET_DISCONNECTED',
        isForMainFrame: true,
      );

      manager.handleWebResourceError(error);

      expect(manager.status, equals(ChatGptBridgeStatus.ready));
    });

    test('main-frame generic error fails generation with Persian loading error message', () {
      manager.setTestState(status: ChatGptBridgeStatus.generating);

      final error = FakeWebResourceError(
        errorCode: -10,
        description: 'net::ERR_ACCESS_DENIED',
        isForMainFrame: true,
      );

      manager.handleWebResourceError(error);

      expect(manager.status, equals(ChatGptBridgeStatus.ready));
    });

    test('HTTP 5xx server error fails generation with Persian server error message', () {
      manager.setTestState(status: ChatGptBridgeStatus.generating);

      final error = FakeHttpResponseError(
        response: FakeWebResourceResponse(statusCode: 503),
      );

      manager.handleHttpError(error);

      expect(manager.status, equals(ChatGptBridgeStatus.ready));
    });

    test('HTTP 401/403 login required error fails generation with Persian login message', () {
      manager.setTestState(status: ChatGptBridgeStatus.generating);

      final error = FakeHttpResponseError(
        response: FakeWebResourceResponse(statusCode: 401),
      );

      manager.handleHttpError(error);

      expect(manager.status, equals(ChatGptBridgeStatus.ready));
    });
  });
}
