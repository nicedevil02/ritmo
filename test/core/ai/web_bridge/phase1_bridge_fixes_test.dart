import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TestWebViewController extends Fake implements WebViewController {
  final List<String> scripts = [];

  @override
  Future<void> runJavaScript(String javaScript) async {
    scripts.add(javaScript);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatGptWebBridgeManager manager;
  late TestWebViewController controller;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
    controller = TestWebViewController();
    BridgeTraceLog.instance.clear();
  });

  tearDown(() {
    manager.cancelTimersForTesting();
    manager.disposeWebView();
    BridgeTraceLog.instance.clear();
  });

  group('Phase 1 Web Bridge Fixes (A-12..A-22, A-40)', () {
    test('A-13: In-flight guard refuses concurrent sendPrompt and yields Persian error', () async {
      final activeController = StreamController<String>();
      final sub = activeController.stream.listen((_) {});
      manager.setTestState(
        status: ChatGptBridgeStatus.generating,
        streamController: activeController,
      );
      manager.setTestRequestId('req_active_1');

      final stream = manager.sendPrompt(prompt: 'پیام دوم همزمان');
      final event = await stream.first;

      expect(event.startsWith('error:'), isTrue);
      expect(event.contains('یک پاسخ در حال دریافت است'), isTrue);

      manager.cancelTimersForTesting();
      await activeController.close();
      await sub.cancel();
    });

    test('A-14: Source lock arbitrates events and ignores done from non-locked source', () async {
      final activeController = StreamController<String>();
      final sub = activeController.stream.listen((_) {});
      manager.setTestState(
        status: ChatGptBridgeStatus.generating,
        streamController: activeController,
      );
      manager.setTestRequestId('req_lock_1');

      // First chunk from SSE locks source to SSE
      manager.handleJsMessageForTest(
        JavaScriptMessage(
          message: jsonEncode({
            'type': 'chunk',
            'delta': 'سلام از SSE',
            'source': 'sse',
            'requestId': 'req_lock_1',
          }),
        ),
      );

      expect(manager.lockedSource?.name, equals('sse'));
      expect(manager.accumulator.text, equals('سلام از SSE'));

      // DOM sends a 'done' event with shorter text — must be ignored because locked source is SSE
      manager.handleJsMessageForTest(
        JavaScriptMessage(
          message: jsonEncode({
            'type': 'done',
            'fullText': 'متن',
            'source': 'dom',
            'requestId': 'req_lock_1',
          }),
        ),
      );

      // Status should still be generating (not terminated by DOM done)
      expect(manager.status, equals(ChatGptBridgeStatus.generating));
      expect(manager.accumulator.text, equals('سلام از SSE'));

      manager.cancelTimersForTesting();
      await activeController.close();
      await sub.cancel();
    });

    test('A-18: handlePageFinished salvages accumulator before aborting on navigation reload loop', () async {
      final activeController = StreamController<String>();
      final sub = activeController.stream.listen((_) {});
      manager.setTestState(
        status: ChatGptBridgeStatus.generating,
        streamController: activeController,
      );
      manager.setTestRequestId('req_nav_loop_1');

      // Accumulator has some text
      manager.handleJsMessageForTest(
        JavaScriptMessage(
          message: jsonEncode({
            'type': 'chunk',
            'delta': 'بخشی از پاسخ که قبل از رفرش دریافت شد',
            'source': 'dom',
            'requestId': 'req_nav_loop_1',
          }),
        ),
      );

      expect(manager.accumulator.isEmpty, isFalse);

      // Exceed reload loop threshold
      for (var i = 1; i <= ChatGptWebBridgeManager.maxNavigationReloads + 1; i++) {
        await manager.handlePageFinished('https://chatgpt.com/c/loop', controller);
      }

      // Generation should finish gracefully (salvaged) rather than hard failing
      expect(manager.status, equals(ChatGptBridgeStatus.ready));
      expect(manager.currentRequestId, isNull);

      manager.cancelTimersForTesting();
      await activeController.close();
      await sub.cancel();
    });

    test('A-22: describeEmptyResponseReason diagnoses correctly', () {
      // Cloudflare state
      manager.setTestState(status: ChatGptBridgeStatus.cloudflareChallenge);
      var reason = manager.describeEmptyResponseReason();
      expect(reason.messageFa.contains('کلودفلر'), isTrue);

      // Auth required state
      manager.setTestState(status: ChatGptBridgeStatus.ready);
      manager.setTestAuthenticated(false);
      reason = manager.describeEmptyResponseReason();
      expect(reason.messageFa.contains('منقضی'), isTrue);

      // Ready state without chunks
      manager.setTestAuthenticated(true);
      reason = manager.describeEmptyResponseReason();
      expect(reason.messageFa.contains('نتوانست متن را از صفحه'), isTrue);
    });

    test('A-40: harvestVisibleAnswer executes __ritmo_forceHarvest script in controller', () async {
      manager.setTestState(controller: controller);
      manager.setTestRequestId('req_harvest_1');

      // Trigger harvest in background
      final future = manager.harvestVisibleAnswer();

      // Controller must have received forceHarvest script
      expect(controller.scripts.any((s) => s.contains('__ritmo_forceHarvest')), isTrue);

      // Simulate JS returning harvest_result event
      manager.handleJsMessageForTest(
        JavaScriptMessage(
          message: jsonEncode({
            'type': 'harvest_result',
            'fullText': 'متن هاروست شده از DOM',
            'requestId': 'req_harvest_1',
            'strategy': 'dom_direct',
            'source': 'dom',
          }),
        ),
      );

      final result = await future;
      expect(result, equals('متن هاروست شده از DOM'));
    });
  });
}
