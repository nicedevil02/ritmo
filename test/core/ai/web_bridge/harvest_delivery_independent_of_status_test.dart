import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
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

  group('DET-14: Harvest Delivery Independent of Status', () {
    test(
      'BridgeHarvestResultEvent delivers text and completes stream even if status is ready',
      () async {
        final streamCtrl = StreamController<String>.broadcast();
        addTearDown(streamCtrl.close);
        final receivedChunks = <String>[];
        final subscription = streamCtrl.stream.listen((chunk) {
          receivedChunks.add(chunk);
        });
        addTearDown(subscription.cancel);

        manager.setTestState(
          status: ChatGptBridgeStatus.ready,
          streamController: streamCtrl,
        );
        manager.setTestRequestId('req_harv_1');

        final msg = JavaScriptMessage(
          message: jsonEncode({
            'type': 'harvest_result',
            'fullText': 'پاسخ کامل استخراج‌شده از DOM',
            'requestId': 'req_harv_1',
            'source': 'harvest',
            'strategy': 'manual_fallback',
          }),
        );

        manager.handleJsMessageForTest(msg);

        // Give microtask event loop a chance to flush
        await Future<void>.delayed(Duration.zero);

        expect(receivedChunks, contains('پاسخ کامل استخراج‌شده از DOM'));
        expect(streamCtrl.isClosed, isTrue);

        final entries = BridgeTraceLog.instance.entries;
        expect(entries.any((e) => e.type == 'harvest_result'), isTrue);
        expect(entries.any((e) => e.type == 'finish'), isTrue);
      },
    );

    test(
      'BridgeHarvestResultEvent logs harvest_rejected_stream_closed when stream controller is closed',
      () async {
        final streamCtrl = StreamController<String>.broadcast();
        await streamCtrl.close();

        manager.setTestState(
          status: ChatGptBridgeStatus.ready,
          streamController: streamCtrl,
        );
        manager.setTestRequestId('req_harv_closed');

        final msg = JavaScriptMessage(
          message: jsonEncode({
            'type': 'harvest_result',
            'fullText': 'پاسخ پس از بسته شدن',
            'requestId': 'req_harv_closed',
            'source': 'harvest',
          }),
        );

        manager.handleJsMessageForTest(msg);

        final entries = BridgeTraceLog.instance.entries;
        final rejected = entries.firstWhere(
          (e) => e.type == 'harvest_rejected_stream_closed',
        );
        expect(rejected.level, equals(BridgeTraceLevel.warn));
        expect(rejected.requestId, equals('req_harv_closed'));
      },
    );
  });
}
