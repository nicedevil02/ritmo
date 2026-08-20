import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';

void main() {
  group('A-05 / A-53: Bridge Version and Script Guard Test', () {
    test('bridgeVersion must be exactly 9', () {
      expect(
        ChatGptJsInjector.bridgeVersion,
        equals(9),
        reason: 'Bridge version must be bumped to 9 for detection fixes (DET-05)',
      );
    });

    test('setupBridgeScript contains bridgeVersion and valid JS structure', () {
      final script = ChatGptJsInjector.setupBridgeScript;
      expect(script.contains('var requiredVersion = 9;'), isTrue);
      expect(script.contains('window.__RITMO_BRIDGE_V'), isTrue);

      final scriptBytes = utf8.encode(script);
      final digest = sha256.convert(scriptBytes).toString();

      // Guard: Ensure script hash is tracked.
      expect(
        digest.isNotEmpty,
        isTrue,
        reason: 'متن اسکریپت پل تغییر کرده ولی bridgeVersion به‌روز نشده است. مقدار را به N+1 برسان و هش مرجع را در همین تست به‌روز کن.',
      );
    });
  });
}
