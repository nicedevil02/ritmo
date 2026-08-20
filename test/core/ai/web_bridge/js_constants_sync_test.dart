import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_bridge_timeouts.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';

void main() {
  group('DET-32: JS Timeout Constants Sync and Magic Numbers Removal', () {
    test('setupBridgeScript injects RITMO_TIMEOUTS with synchronized values from ChatGptBridgeTimeouts', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('var RITMO_TIMEOUTS = {'), isTrue);
      final expectedWatcherMs = ChatGptBridgeTimeouts.generationTimeout.inMilliseconds - 10000;
      expect(script.contains('watcherTimeoutMs: $expectedWatcherMs'), isTrue);
      expect(script.contains('streamPollIntervalMs: ${ChatGptBridgeTimeouts.heartbeatInterval.inMilliseconds}'), isTrue);
      expect(script.contains('fastPollMs: ${ChatGptBridgeTimeouts.pollFastInterval.inMilliseconds}'), isTrue);

      // Verify usage of RITMO_TIMEOUTS instead of hardcoded numbers in logic
      expect(script.contains('if (totalDuration > RITMO_TIMEOUTS.watcherTimeoutMs)'), isTrue);
      expect(script.contains('cfCheckTimer = setInterval(checkSecurityAndBlockStatus, RITMO_TIMEOUTS.cfCheckIntervalMs)'), isTrue);
      expect(script.contains('}, RITMO_TIMEOUTS.streamPollIntervalMs);'), isTrue);
    });
  });
}
