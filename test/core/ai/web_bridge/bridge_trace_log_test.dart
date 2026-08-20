import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';

void main() {
  group('A-01: BridgeTraceLog', () {
    late BridgeTraceLog log;

    setUp(() {
      log = BridgeTraceLog.instance;
      log.clear();
    });

    test(
      'records entries and limits to maxEntries (300) in circular buffer',
      () {
        for (var i = 0; i < 350; i++) {
          log.addEntry(
            type: 'chunk',
            source: 'dom',
            requestId: 'req_$i',
            textLength: i * 10,
            note: 'entry_$i',
          );
        }

        expect(log.entries.length, equals(BridgeTraceLog.maxEntries));
        expect(log.entries.length, equals(300));
        // First 50 were evicted, oldest entry should be req_50
        expect(log.entries.first.requestId, equals('req_50'));
        expect(log.entries.last.requestId, equals('req_349'));
      },
    );

    test('clear empties the buffer', () {
      log.addEntry(type: 'ready', source: 'lifecycle');
      expect(log.entries.length, equals(1));
      log.clear();
      expect(log.entries.isEmpty, isTrue);
    });

    test(
      'exportAsText produces formatted log output without leaking full message text',
      () {
        log.addEntry(
          type: 'chunk',
          source: 'sse',
          requestId: 'req_xyz',
          textLength: 42,
          note: 'first_token_received',
          level: BridgeTraceLevel.info,
        );

        final exported = log.exportAsText();
        expect(
          exported.contains('=== RITMO CHATGPT WEB BRIDGE TRACE LOG ==='),
          isTrue,
        );
        expect(exported.contains('req=req_xyz'), isTrue);
        expect(exported.contains('len=42'), isTrue);
        expect(exported.contains('src=sse'), isTrue);
        expect(exported.contains('note="first_token_received"'), isTrue);
      },
    );
  });
}
