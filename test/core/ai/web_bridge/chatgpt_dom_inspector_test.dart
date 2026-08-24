import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_dom_inspector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatGptDomInspector Tests', () {
    setUp(() {
      BridgeTraceLog.instance.clear();
      BridgeTraceLog.instance.addEntry(
        type: 'test_event',
        source: 'inspector_test',
        note: 'sample trace entry',
      );
    });

    test('captureSnapshot with null controller produces formatted diagnostic report with trace logs', () async {
      final report = await ChatGptDomInspector.captureSnapshot(
        null,
        currentStatus: 'booting',
        lastError: 'Test error message',
        includeFullHtml: true,
      );

      expect(report.contains('RITMO CHATGPT WEB BRIDGE DIAGNOSTIC REPORT'), isTrue);
      expect(report.contains('Bridge Status: booting'), isTrue);
      expect(report.contains('Last Recorded Error: Test error message'), isTrue);
      expect(report.contains('WebViewController is null'), isTrue);
      expect(report.contains('RECENT BRIDGE TRACE LOGS:'), isTrue);
      expect(report.contains('sample trace entry'), isTrue);
    });
  });
}
