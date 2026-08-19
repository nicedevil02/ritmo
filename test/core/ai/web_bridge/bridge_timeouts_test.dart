import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_bridge_timeouts.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WEB-24: ChatGptBridgeTimeouts Single Source of Truth', () {
    test('ChatGptBridgeTimeouts constants have valid and expected durations', () {
      expect(ChatGptBridgeTimeouts.bootTimeout, equals(const Duration(seconds: 60)));
      expect(ChatGptBridgeTimeouts.generationTimeout, equals(const Duration(seconds: 180)));
      expect(ChatGptBridgeTimeouts.inactivityTimeout, equals(const Duration(minutes: 5)));
      expect(ChatGptBridgeTimeouts.firstTokenTimeout, equals(const Duration(seconds: 60)));
      expect(ChatGptBridgeTimeouts.composerReadyTimeout, equals(const Duration(seconds: 8)));
      expect(ChatGptBridgeTimeouts.heartbeatInterval, equals(const Duration(milliseconds: 350)));
      expect(ChatGptBridgeTimeouts.resendMaxWindow, equals(const Duration(seconds: 15)));
      expect(ChatGptBridgeTimeouts.pollFastInterval, equals(const Duration(milliseconds: 200)));
    });

    test('ChatGptWebBridgeManager references ChatGptBridgeTimeouts constants', () {
      expect(
        ChatGptWebBridgeManager.inactivityTimeout,
        equals(ChatGptBridgeTimeouts.inactivityTimeout),
      );
      expect(
        ChatGptWebBridgeManager.generationTimeout,
        equals(ChatGptBridgeTimeouts.generationTimeout),
      );
    });
  });
}
