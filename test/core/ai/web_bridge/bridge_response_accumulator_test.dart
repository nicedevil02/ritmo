import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_response_accumulator.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';

void main() {
  group('A-03: BridgeResponseAccumulator', () {
    late BridgeResponseAccumulator accumulator;

    setUp(() {
      accumulator = BridgeResponseAccumulator();
      BridgeTraceLog.instance.clear();
    });

    test('Case 1 & 2: Empty incoming text or unchanged text returns null', () {
      expect(accumulator.applyFull('', source: 'dom'), isNull);
      expect(accumulator.applyFull('   ', source: 'dom'), isNull);

      final first = accumulator.applyFull('سلام کاربر عزیز', source: 'dom');
      expect(first, isNotNull);
      expect(first!.delta, equals('سلام کاربر عزیز'));
      expect(first.isRewrite, isFalse);

      // Same text applied again -> null
      final repeat = accumulator.applyFull('سلام کاربر عزیز', source: 'dom');
      expect(repeat, isNull);
    });

    test('Case 3: Initial non-empty input on empty accumulator produces full delta', () {
      expect(accumulator.isEmpty, isTrue);
      expect(accumulator.length, equals(0));

      final res = accumulator.applyFull('پاسخ اولیه', source: 'dom');
      expect(res, isNotNull);
      expect(res!.delta, equals('پاسخ اولیه'));
      expect(res.fullText, equals('پاسخ اولیه'));
      expect(res.isRewrite, isFalse);
      expect(accumulator.text, equals('پاسخ اولیه'));
      expect(accumulator.length, equals('پاسخ اولیه'.length));
    });

    test('Case 4: Progressive prefix growth computes exact suffix delta', () {
      accumulator.applyFull('سلام', source: 'dom');
      final res = accumulator.applyFull('سلام کاربر عزیز، حالت چطوره؟', source: 'dom');

      expect(res, isNotNull);
      expect(res!.delta, equals(' کاربر عزیز، حالت چطوره؟'));
      expect(res.fullText, equals('سلام کاربر عزیز، حالت چطوره؟'));
      expect(res.isRewrite, isFalse);
      expect(accumulator.text, equals('سلام کاربر عزیز، حالت چطوره؟'));
    });

    test('Case 5: Divergent non-prefix rewrite yields isRewrite = true and fullText', () {
      accumulator.applyFull('سلام من دستیار هستم', source: 'dom');
      final res = accumulator.applyFull('درود بر شما! من دستیار هوشمند شما هستم.', source: 'dom');

      expect(res, isNotNull);
      expect(res!.isRewrite, isTrue);
      expect(res.delta, equals('درود بر شما! من دستیار هوشمند شما هستم.'));
      expect(res.fullText, equals('درود بر شما! من دستیار هوشمند شما هستم.'));
      expect(accumulator.text, equals('درود بر شما! من دستیار هوشمند شما هستم.'));
    });

    test('Case 6: Transient DOM retreat is ignored and returns null', () {
      accumulator.applyFull('یک متن طولانی و کامل برای آزمایش عقب‌گرد', source: 'dom');
      final retreat = accumulator.applyFull('یک متن طولانی', source: 'dom');

      expect(retreat, isNull);
      expect(accumulator.text, equals('یک متن طولانی و کامل برای آزمایش عقب‌گرد'));
      expect(
        BridgeTraceLog.instance.entries.any((e) => e.type == 'accumulator_retreat'),
        isTrue,
      );
    });

    test('Case 7: Delta accumulation via applyDelta', () {
      final d1 = accumulator.applyDelta('بخش اول ', source: 'sse');
      expect(d1, isNotNull);
      expect(d1!.delta, equals('بخش اول '));
      expect(d1.fullText, equals('بخش اول '));

      final d2 = accumulator.applyDelta('بخش دوم', source: 'sse');
      expect(d2, isNotNull);
      expect(d2!.delta, equals('بخش دوم'));
      expect(d2.fullText, equals('بخش اول بخش دوم'));
      expect(accumulator.text, equals('بخش اول بخش دوم'));
    });

    test('Case 8: Strips ChatGPT said: noise prefix', () {
      final res = accumulator.applyFull('ChatGPT said:\nاین یک پاسخ واقعی است.', source: 'dom');
      expect(res, isNotNull);
      expect(res!.fullText, equals('این یک پاسخ واقعی است.'));
    });

    test('reset clears accumulator text', () {
      accumulator.applyFull('متن تستی', source: 'dom');
      expect(accumulator.isEmpty, isFalse);
      accumulator.reset();
      expect(accumulator.isEmpty, isTrue);
      expect(accumulator.text, equals(''));
    });
  });
}
