import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A-91: BridgeTraceLog Lifecycle and Export Tests', () {
    late BridgeTraceLog log;

    setUp(() {
      log = BridgeTraceLog.instance;
      log.clear();
    });

    tearDown(() {
      log.clear();
    });

    test('records entries and enforces maxCapacity of 500', () {
      expect(log.entries, isEmpty);

      for (var i = 0; i < 550; i++) {
        log.addEntry(
          type: 'test_event_$i',
          source: 'test',
          level: i % 2 == 0 ? BridgeTraceLevel.info : BridgeTraceLevel.warn,
        );
      }

      expect(log.entries.length, equals(300));
      expect(log.entries.first.type, equals('test_event_250'));
      expect(log.entries.last.type, equals('test_event_549'));
    });

    test('exportAsText produces formatted log containing entries', () {
      log.addEntry(
        type: 'send_prompt',
        source: 'dart',
        requestId: 'req_test_1',
        note: 'Prompt dispatched',
      );
      log.addEntry(
        type: 'first_token',
        source: 'sse',
        requestId: 'req_test_1',
        note: 'TTFT received',
      );

      final exported = log.exportAsText();
      expect(exported, contains('=== RITMO CHATGPT WEB BRIDGE TRACE LOG ==='));
      expect(
        exported,
        contains(
          '[INFO] type=send_prompt src=dart req=req_test_1 note="Prompt dispatched"',
        ),
      );
      expect(exported, contains('TTFT received'));
    });
  });
}
