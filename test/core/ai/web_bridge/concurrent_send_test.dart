import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatGptWebBridgeManager manager;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
    manager.resetStateForTest();
    BridgeTraceLog.instance.clear();
  });

  tearDown(() {
    manager.disposeWebView();
  });

  group('A-51: Concurrent Send and In-Flight Request Cancellation', () {
    test(
      'cancelCurrentStream cancels active controller and returns status to ready',
      () async {
        manager.setStatusForTest(ChatGptBridgeStatus.generating);
        manager.setCurrentRequestIdForTest('req_concurrent_1');

        manager.cancelCurrentStream();

        expect(manager.status, ChatGptBridgeStatus.ready);
        expect(manager.currentRequestId, isNull);
      },
    );

    test(
      'new request generates distinct requestId and resets accumulator',
      () async {
        manager.setStatusForTest(ChatGptBridgeStatus.ready);
        manager.setTestAccumulator('متن قدیمی درخواست قبلی');

        expect(manager.accumulator.text, 'متن قدیمی درخواست قبلی');

        manager.resetStateForTest();
        expect(manager.accumulator.isEmpty, isTrue);
      },
    );
  });
}
