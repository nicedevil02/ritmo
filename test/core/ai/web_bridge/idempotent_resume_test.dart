import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';

void main() {
  group('DET-21: Idempotent Resume and Watcher Guard', () {
    test('setupBridgeScript contains duplicate resume guard and cleaner timers', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('window.__ritmo_watcher_running && window.__ritmo_active_req_id === reqId'), isTrue);
      expect(script.contains("notifyFlutter('resume_skipped_duplicate'"), isTrue);
      expect(script.contains('window.__ritmo_watcher_running = true;'), isTrue);
      expect(script.contains('window.__ritmo_watcher_running = false;'), isTrue);
    });

    test('WebBridgeEvent parses resume_skipped_duplicate correctly', () {
      final event = WebBridgeEvent.parse('''{
        "type": "resume_skipped_duplicate",
        "requestId": "req_resume_21",
        "source": "dom"
      }''');

      expect(event, isA<BridgeResumeSkippedDuplicateEvent>());
      final dupEvent = event as BridgeResumeSkippedDuplicateEvent;
      expect(dupEvent.requestId, equals('req_resume_21'));
      expect(dupEvent.source, equals('dom'));
    });
  });
}
