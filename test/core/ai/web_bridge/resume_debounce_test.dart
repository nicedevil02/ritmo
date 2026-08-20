import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

class RecordingWebViewController extends Fake implements WebViewController {
  final List<String> executedScripts = [];

  @override
  Future<void> runJavaScript(String javaScript) async {
    executedScripts.add(javaScript);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatGptWebBridgeManager manager;
  late RecordingWebViewController controller;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
    controller = RecordingWebViewController();
    BridgeTraceLog.instance.clear();
  });

  tearDown(() {
    manager.resetStateForTest();
  });

  group('DET-22: Debounce Resume Invocations on Rapid Page Transitions', () {
    test('rapid handlePageFinished calls debounce __ritmo_resume invocation to single execution', () async {
      final streamCtrl = StreamController<String>.broadcast();
      addTearDown(streamCtrl.close);

      manager.setTestState(
        status: ChatGptBridgeStatus.generating,
        streamController: streamCtrl,
      );
      manager.setTestRequestId('req_debounce_22');
      manager.setTestPendingRequest(
        PendingWebBridgeRequest(
          requestId: 'req_debounce_22',
          promptHash: 'hash_22',
          promptText: 'Hello',
          sentAt: DateTime.now(),
          stage: PendingRequestStage.streaming,
        ),
      );

      // Call handlePageFinished 3 times rapidly
      await manager.handlePageFinished('https://chatgpt.com/c/1', controller);
      await Future.delayed(const Duration(milliseconds: 100));
      await manager.handlePageFinished('https://chatgpt.com/c/2', controller);
      await Future.delayed(const Duration(milliseconds: 100));
      await manager.handlePageFinished('https://chatgpt.com/c/3', controller);

      // At this point, resumeDebounceTimer should be active, but __ritmo_resume should NOT have run yet
      expect(manager.resumeDebounceTimerForTest != null, isTrue);
      final resumeCountBefore = controller.executedScripts.where((s) => s.contains('window.__ritmo_resume(')).length;
      expect(resumeCountBefore, equals(0));

      // Check trace log has recorded resume_debounced
      final entries = BridgeTraceLog.instance.entries.where((e) => e.type == 'resume_debounced');
      expect(entries.length, equals(3));

      // Wait for debounce timer to fire (550ms)
      await Future.delayed(const Duration(milliseconds: 550));

      final resumeCountAfter = controller.executedScripts.where((s) => s.contains('window.__ritmo_resume(')).length;
      expect(resumeCountAfter, equals(1));
    });
  });
}
