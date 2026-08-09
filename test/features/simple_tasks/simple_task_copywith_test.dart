import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';

void main() {
  group('SimpleTask.copyWith', () {
    test('should allow nulling out fields', () {
      final now = DateTime.now();
      final task = SimpleTask(
        id: '1',
        title: 'Test',
        note: 'Note',
        dueDate: '2023-01-01',
        dueTime: '12:00',
        reminderAtMs: 12345,
        reminderId: 'rem1',
        linkedRoutineId: 'rout1',
        importantAt: now,
        doneAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final cleared = task.copyWith(
        note: null,
        dueDate: null,
        dueTime: null,
        reminderAtMs: null,
        reminderId: null,
        linkedRoutineId: null,
        importantAt: null,
        doneAt: null,
      );

      expect(cleared.note, isNull);
      expect(cleared.dueDate, isNull);
      expect(cleared.dueTime, isNull);
      expect(cleared.reminderAtMs, isNull);
      expect(cleared.reminderId, isNull);
      expect(cleared.linkedRoutineId, isNull);
      expect(cleared.importantAt, isNull);
      expect(cleared.doneAt, isNull);
    });

    test('should keep original values if not specified', () {
      final now = DateTime.now();
      final task = SimpleTask(
        id: '1',
        title: 'Test',
        note: 'Note',
        dueDate: '2023-01-01',
        createdAt: now,
        updatedAt: now,
      );

      final unchanged = task.copyWith();

      expect(unchanged.note, 'Note');
      expect(unchanged.dueDate, '2023-01-01');
    });
  });
}
