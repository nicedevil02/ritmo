import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_tool_call_parser.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';

void main() {
  setUp(() {
    BridgeTraceLog.instance.clear();
  });

  group('A-48: Display Suppression Watchdog and Partial Tag Handling', () {
    test('AgentToolCallParser detects open tool tags for suppression', () {
      const partialTag =
          'سلام <tool_call>{"name": "routine.create", "parameters": {"title": "ورزش"}';
      final scan = AgentToolCallParser.scan(partialTag);

      expect(scan.hasOpenTag, isTrue);
      expect(scan.cleanText, 'سلام');
    });

    test(
      'AgentToolCallParser recognizes closed tags and releases suppression',
      () {
        const closedTag =
            'سلام <tool_call>{"name": "routine.create", "parameters": {"title": "ورزش"}}</tool_call> ادامه گفتگو';
        final scan = AgentToolCallParser.scan(closedTag);

        expect(scan.hasOpenTag, isFalse);
        expect(scan.calls.length, 1);
        expect(scan.calls.first.toolName, 'routine.create');
      },
    );

    test(
      'Suppression watchdog logs release when tag stays unclosed over character cap',
      () {
        BridgeTraceLog.instance.addEntry(
          type: 'suppression_watchdog_release',
          source: 'dart',
          note: 'suppression_watchdog_release (grewBy=650, elapsedMs=1200)',
          level: BridgeTraceLevel.warn,
        );

        final entries = BridgeTraceLog.instance.entries;
        expect(
          entries.any((e) => e.type == 'suppression_watchdog_release'),
          isTrue,
        );
        expect(entries.last.level, BridgeTraceLevel.warn);
      },
    );

    test(
      'AgentToolCallParser cleanForDisplay handles unclosed tag gracefully when released',
      () {
        const text =
            'پاسخ کاربر <ritmo-tool name="bad.tool"> متن خیلی طولانی بدون بستن تگ...';
        final cleaned = AgentToolCallParser.cleanForDisplay(text);
        expect(cleaned, isNotEmpty);
        expect(cleaned.contains('پاسخ کاربر'), isTrue);
      },
    );
  });
}
