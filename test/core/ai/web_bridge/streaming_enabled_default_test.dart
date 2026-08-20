import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  late ChatGptWebBridgeManager manager;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
  });

  tearDown(() {
    manager.resetStateForTest();
  });

  group('DET-34: Streaming Enabled by Default', () {
    test('enableWebBridgeStreaming is true by default', () {
      expect(ChatGptWebBridgeManager.enableWebBridgeStreaming, isTrue);
    });

    test('emitting chunk pushes delta immediately to streamController when streaming is enabled', () async {
      final streamCtrl = StreamController<String>.broadcast();
      addTearDown(streamCtrl.close);

      manager.setTestState(
        status: ChatGptBridgeStatus.generating,
        streamController: streamCtrl,
      );

      final receivedChunks = <String>[];
      streamCtrl.stream.listen((chunk) {
        receivedChunks.add(chunk);
      });

      manager.handleJsMessageForTest(const JavaScriptMessage(
        message: '{"type":"chunk","delta":"سلام دوست عزیز","source":"dom"}',
      ));

      await Future.delayed(Duration.zero);

      expect(receivedChunks, contains('سلام دوست عزیز'));
    });
  });
}
