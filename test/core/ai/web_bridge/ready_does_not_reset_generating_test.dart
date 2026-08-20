import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  group('DET-12: Ready Event Does Not Reset Generating Status', () {
    test(
      'Receiving ready event while generating leaves status intact and logs ready_ignored_during_generation',
      () {
        BridgeTraceLog.instance.clear();
        final manager = ChatGptWebBridgeManager.instance;

        manager.setTestState(status: ChatGptBridgeStatus.generating);
        manager.setTestRequestId('req_gen_123');
        expect(manager.status, equals(ChatGptBridgeStatus.generating));

        final msg = JavaScriptMessage(
          message: jsonEncode({
            'type': 'ready',
            'version': 9,
            'isWarm': true,
            'currentPath': '/c/684df39c-1481-8321-953e-ecb4f8d95181',
            'hasComposer': true,
            'isAuthed': true,
            'source': 'lifecycle',
          }),
        );

        manager.handleJsMessageForTest(msg);

        // Status must remain generating!
        expect(manager.status, equals(ChatGptBridgeStatus.generating));

        // Trace log must contain ready_ignored_during_generation
        final entries = BridgeTraceLog.instance.entries;
        final ignoredEntry = entries.firstWhere(
          (e) => e.type == 'ready_ignored_during_generation',
        );
        expect(ignoredEntry.level, equals(BridgeTraceLevel.info));
        expect(ignoredEntry.note, contains('warm=true'));
        expect(
          ignoredEntry.note,
          contains('path=/c/684df39c-1481-8321-953e-ecb4f8d95181'),
        );
        expect(ignoredEntry.requestId, equals('req_gen_123'));

        manager.resetStateForTest();
      },
    );
  });
}
