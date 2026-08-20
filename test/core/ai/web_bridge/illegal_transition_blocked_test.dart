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

  group('DET-15: Central Generating Status Guard', () {
    test(
      'setStatus directly to ready while generating with active stream is blocked and logged',
      () async {
        final streamCtrl = StreamController<String>.broadcast();
        addTearDown(streamCtrl.close);

        manager.setTestState(
          status: ChatGptBridgeStatus.generating,
          streamController: streamCtrl,
        );
        manager.setTestRequestId('req_guard_15');
        expect(manager.status, equals(ChatGptBridgeStatus.generating));

        // Attempt to change status to ready directly without finishing/failing
        manager.setStatusForTest(ChatGptBridgeStatus.ready);

        // Status must remain generating!
        expect(manager.status, equals(ChatGptBridgeStatus.generating));

        final entries = BridgeTraceLog.instance.entries;
        final blocked = entries.firstWhere(
          (e) => e.type == 'illegal_status_transition_blocked',
        );
        expect(blocked.level, equals(BridgeTraceLevel.warn));
        expect(blocked.note, contains('from_generating_to_ready'));
        expect(blocked.requestId, equals('req_guard_15'));
      },
    );

    test(
      'setStatus to error or cloudflareChallenge or vpnRequired is allowed from generating',
      () async {
        final streamCtrl = StreamController<String>.broadcast();
        addTearDown(streamCtrl.close);

        manager.setTestState(
          status: ChatGptBridgeStatus.generating,
          streamController: streamCtrl,
        );

        manager.setStatusForTest(ChatGptBridgeStatus.cloudflareChallenge);
        expect(manager.status, equals(ChatGptBridgeStatus.cloudflareChallenge));
      },
    );
  });
}
