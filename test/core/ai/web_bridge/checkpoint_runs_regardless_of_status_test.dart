import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
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

  group('DET-13: Checkpoint Runs Regardless of Status', () {
    test('runCheckpointCheck executes and logs checkpoint_check_started when controller is identical even if status is ready', () async {
      final streamCtrl = StreamController<String>.broadcast();

      manager.setTestState(
        status: ChatGptBridgeStatus.ready,
        streamController: streamCtrl,
      );
      manager.setTestRequestId('req_chk_1');

      await manager.runCheckpointCheckForTesting(1, streamCtrl, 'req_chk_1');

      final entries = BridgeTraceLog.instance.entries;
      final startedEntry = entries.firstWhere((e) => e.type == 'checkpoint_check_started');
      expect(startedEntry.requestId, equals('req_chk_1'));
      expect(startedEntry.note, equals('checkpoint_1'));

      await streamCtrl.close();
    });

    test('runCheckpointCheck logs checkpoint_skipped when stream controller does not match', () async {
      final activeCtrl = StreamController<String>.broadcast();
      final staleCtrl = StreamController<String>.broadcast();

      manager.setTestState(
        status: ChatGptBridgeStatus.generating,
        streamController: activeCtrl,
      );

      await manager.runCheckpointCheckForTesting(1, staleCtrl, 'req_stale_1');

      final entries = BridgeTraceLog.instance.entries;
      final skippedEntry = entries.firstWhere((e) => e.type == 'checkpoint_skipped');
      expect(skippedEntry.note, contains('skipped_controller_mismatch'));

      await activeCtrl.close();
      await staleCtrl.close();
    });
  });
}
