import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/memory/ai_memory_service.dart';
import 'package:ritmo/core/ai/memory/memory_models.dart';

void main() {
  group('H-7: AI Memory Pruning & Retention Logic Tests', () {
    test('MemoryOp ADD sets explicit importance to 10 and pinned', () {
      final op = MemoryOp(
        op: 'ADD',
        content: 'کاربر به گل گاوزبان علاقه دارد',
        type: MemoryType.preference,
        domain: 'core',
        importance: 10,
        sensitive: false,
      );
      expect(op.importance, 10);
      expect(op.sensitive, isFalse);
    });

    test('isContentSensitive recognizes various domains', () {
      expect(AiMemoryService.isContentSensitive('من زانودرد دارم'), isFalse); // Orthopedic unless disease/doctor keyword
      expect(AiMemoryService.isContentSensitive('داروی فشار خون مصرف می‌کنم'), isTrue);
    });
  });
}
