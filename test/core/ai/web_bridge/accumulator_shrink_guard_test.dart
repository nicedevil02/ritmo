import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_response_accumulator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A-90: BridgeResponseAccumulator Shrink Guard Tests', () {
    test('applyDelta continuously grows text', () {
      final acc = BridgeResponseAccumulator();
      expect(acc.isEmpty, isTrue);

      acc.applyDelta('بخش اول ', source: 'sse');
      expect(acc.text, equals('بخش اول '));
      expect(acc.length, equals(8));

      acc.applyDelta('بخش دوم', source: 'sse');
      expect(acc.text, equals('بخش اول بخش دوم'));
      expect(acc.length, equals(15));
    });

    test('applyFull ignores transient dom retreat when incoming is shorter prefix', () {
      final acc = BridgeResponseAccumulator();
      acc.applyDelta('متن بلندتر آزمایشی', source: 'sse');
      final originalLength = acc.length;

      // Attempt applyFull with shorter prefix text -> transient retreat ignored
      final delta = acc.applyFull('متن بلندتر', source: 'dom');
      expect(delta, isNull);
      expect(acc.length, equals(originalLength));
      expect(acc.text, equals('متن بلندتر آزمایشی'));

      // Attempt applyFull with longer text -> accepted
      final deltaLonger = acc.applyFull('متن بلندتر آزمایشی به همراه توضیحات تکمیلی', source: 'dom');
      expect(deltaLonger, isNotNull);
      expect(acc.text, equals('متن بلندتر آزمایشی به همراه توضیحات تکمیلی'));
    });
  });
}
