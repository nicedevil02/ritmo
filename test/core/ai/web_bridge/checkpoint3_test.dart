import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_bridge_timeouts.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';

void main() {
  late ChatGptWebBridgeManager manager;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
    BridgeTraceLog.instance.clear();
  });

  tearDown(() {
    manager.resetStateForTest();
  });

  group('DET-30: Checkpoint 3 Setup and Execution', () {
    test('ChatGptBridgeTimeouts defines checkpoint3Delay', () {
      expect(ChatGptBridgeTimeouts.checkpoint3Delay, isNotNull);
      expect(
        ChatGptBridgeTimeouts.checkpoint3Delay.inSeconds,
        greaterThanOrEqualTo(25),
      );
    });

    test(
      'runCheckpointCheck executes checkpoint 3 and logs checkpoint_3 note',
      () async {
        final streamCtrl = StreamController<String>.broadcast();
        manager.setTestState(
          status: ChatGptBridgeStatus.generating,
          streamController: streamCtrl,
        );
        manager.setTestRequestId('req_cp3_test');

        await manager.runCheckpointCheckForTesting(
          3,
          streamCtrl,
          'req_cp3_test',
        );

        final entries = BridgeTraceLog.instance.entries;
        final startedEntry = entries.firstWhere(
          (e) => e.type == 'checkpoint_check_started',
        );
        expect(startedEntry.note, equals('checkpoint_3'));
        expect(startedEntry.requestId, equals('req_cp3_test'));

        await streamCtrl.close();
      },
    );
  });
}
