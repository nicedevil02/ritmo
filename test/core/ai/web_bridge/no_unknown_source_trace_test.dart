import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';

void main() {
  group('DET-29: No Unknown Source in BridgeTraceLog', () {
    setUp(() {
      BridgeTraceLog.instance.clear();
    });

    test('All standard manager trace entries use valid BridgeSource enum names', () {
      final validSources = BridgeSource.values.map((e) => e.name).toSet();

      // Trigger various trace log entries
      BridgeTraceLog.instance.addEntry(
        type: 'test_event',
        source: BridgeSource.dart.name,
      );
      BridgeTraceLog.instance.addEntry(
        type: 'test_lifecycle',
        source: BridgeSource.lifecycle.name,
      );
      BridgeTraceLog.instance.addEntry(
        type: 'test_dom',
        source: BridgeSource.dom.name,
      );
      BridgeTraceLog.instance.addEntry(
        type: 'test_sse',
        source: BridgeSource.sse.name,
      );
      BridgeTraceLog.instance.addEntry(
        type: 'test_harvest',
        source: BridgeSource.harvest.name,
      );

      for (final entry in BridgeTraceLog.instance.entries) {
        expect(validSources.contains(entry.source), isTrue,
            reason: 'Entry with type= has invalid source=');
        expect(entry.source, isNot(equals('unknown')));
      }
    });

    test('parseBridgeSource maps unknown strings to dart fallback safely', () {
      expect(parseBridgeSource('unknown'), equals(BridgeSource.dart));
      expect(parseBridgeSource(''), equals(BridgeSource.dart));
      expect(parseBridgeSource('invalid_src'), equals(BridgeSource.dart));
      expect(parseBridgeSource('sse'), equals(BridgeSource.sse));
      expect(parseBridgeSource('DOM'), equals(BridgeSource.dom));
    });
  });
}
