import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_response_accumulator.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';

void main() {
  late BridgeResponseAccumulator accumulator;

  setUp(() {
    accumulator = BridgeResponseAccumulator();
    BridgeTraceLog.instance.clear();
  });

  group('A-49: Accumulator Shrink & Transient DOM Retreat Protection', () {
    test('ignores incoming text that is shorter than current accumulated text', () {
      // 1. Initial text chunk
      final chunk1 = accumulator.applyFull('سلام، چطور می‌توانم کمکتان کنم؟', source: 'dom');
      expect(chunk1, isNotNull);
      expect(chunk1!.isRewrite, isFalse);
      expect(accumulator.text, 'سلام، چطور می‌توانم کمکتان کنم؟');

      // 2. Longer text chunk
      final chunk2 = accumulator.applyFull('سلام، چطور می‌توانم کمکتان کنم؟ امروز برنامه شما...', source: 'dom');
      expect(chunk2, isNotNull);
      expect(chunk2!.delta, ' امروز برنامه شما...');
      expect(accumulator.text, 'سلام، چطور می‌توانم کمکتان کنم؟ امروز برنامه شما...');

      // 3. Transient shrink in DOM (e.g. temporary node removal during re-render)
      final shrinkChunk = accumulator.applyFull('سلام، چطور', source: 'dom');
      expect(shrinkChunk, isNull, reason: 'Transient DOM retreat must be ignored');
      expect(
        accumulator.text,
        'سلام، چطور می‌توانم کمکتان کنم؟ امروز برنامه شما...',
        reason: 'Accumulator text must not shrink or lose state',
      );
    });

    test('recovers smoothly when DOM restores full text after transient shrink', () {
      accumulator.applyFull('بخش اول متن پاسخ دستیار', source: 'dom');
      expect(accumulator.text, 'بخش اول متن پاسخ دستیار');

      // Transient shrink ignored
      expect(accumulator.applyFull('بخش', source: 'dom'), isNull);

      // Subsequent growth after recovery
      final recovered = accumulator.applyFull('بخش اول متن پاسخ دستیار و بخش جدید اضافه شده', source: 'dom');
      expect(recovered, isNotNull);
      expect(recovered!.delta, ' و بخش جدید اضافه شده');
      expect(accumulator.text, 'بخش اول متن پاسخ دستیار و بخش جدید اضافه شده');
    });

    test('reset clears accumulated text properly', () {
      accumulator.applyFull('متن موقت', source: 'dom');
      expect(accumulator.text, 'متن موقت');

      accumulator.reset();
      expect(accumulator.text, isEmpty);
      expect(accumulator.length, 0);
    });
  });
}
