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

  group('DET-23: Separate Cold Navigation from In-Flight Reload Counter', () {
    test(
      'cold navigations increment coldNavigationCount without affecting navigationReloadCount',
      () async {
        expect(manager.navigationReloadCount, equals(0));
        expect(manager.coldNavigationCount, equals(0));

        await manager.handlePageFinished('https://chatgpt.com/', controller);
        await manager.handlePageFinished('https://chatgpt.com/', controller);

        expect(manager.coldNavigationCount, equals(2));
        expect(manager.navigationReloadCount, equals(0));

        final coldEntries = BridgeTraceLog.instance.entries.where(
          (e) => e.type == 'cold_navigation_finished',
        );
        expect(coldEntries.length, equals(2));
      },
    );

    test(
      'in-flight navigations increment navigationReloadCount and record trace',
      () async {
        manager.setTestState(status: ChatGptBridgeStatus.generating);
        manager.setTestRequestId('req_counter_23');
        manager.setTestPendingRequest(
          PendingWebBridgeRequest(
            requestId: 'req_counter_23',
            promptHash: 'hash_23',
            promptText: 'Test prompt',
            sentAt: DateTime.now(),
            stage: PendingRequestStage.streaming,
          ),
        );

        await manager.handlePageFinished(
          'https://chatgpt.com/c/123',
          controller,
        );

        expect(manager.navigationReloadCount, equals(1));
        expect(manager.coldNavigationCount, equals(0));

        final inFlightEntries = BridgeTraceLog.instance.entries.where(
          (e) => e.type == 'in_flight_navigation_finished',
        );
        expect(inFlightEntries.length, equals(1));
        expect(inFlightEntries.first.requestId, equals('req_counter_23'));
      },
    );

    test('resetStateForTest resets both counters to 0', () async {
      await manager.handlePageFinished('https://chatgpt.com/', controller);
      expect(manager.coldNavigationCount, equals(1));

      manager.resetStateForTest();

      expect(manager.coldNavigationCount, equals(0));
      expect(manager.navigationReloadCount, equals(0));
    });
  });
}
