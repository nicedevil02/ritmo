import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/commands/command_stack.dart';

class MockTestCommand implements UndoableCommand {
  MockTestCommand(this.description);

  @override
  final String description;

  int executeCount = 0;
  int undoCount = 0;

  @override
  Future<void> execute() async {
    executeCount++;
  }

  @override
  Future<void> undo() async {
    undoCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-44: Undo / Redo CommandStack Implementation', () {
    setUp(() {
      CommandStack.instance.clear();
    });

    test('Pushing command allows undo and exposes description', () async {
      final cmd = MockTestCommand('Move Task');
      CommandStack.instance.push(cmd);

      expect(CommandStack.instance.canUndo, isTrue);
      expect(CommandStack.instance.canRedo, isFalse);
      expect(CommandStack.instance.lastUndoDescription, equals('Move Task'));

      final undone = await CommandStack.instance.undoLast();
      expect(undone, isTrue);
      expect(cmd.undoCount, equals(1));
      expect(CommandStack.instance.canUndo, isFalse);
      expect(CommandStack.instance.canRedo, isTrue);
      expect(CommandStack.instance.lastRedoDescription, equals('Move Task'));

      final redone = await CommandStack.instance.redoLast();
      expect(redone, isTrue);
      expect(cmd.executeCount, equals(1));
      expect(CommandStack.instance.canUndo, isTrue);
      expect(CommandStack.instance.canRedo, isFalse);
    });

    test('Pushing a new command clears redo history', () async {
      final cmd1 = MockTestCommand('Action 1');
      final cmd2 = MockTestCommand('Action 2');

      CommandStack.instance.push(cmd1);
      await CommandStack.instance.undoLast();
      expect(CommandStack.instance.canRedo, isTrue);

      // New action pushed
      CommandStack.instance.push(cmd2);
      expect(CommandStack.instance.canRedo, isFalse);
      expect(CommandStack.instance.canUndo, isTrue);
      expect(CommandStack.instance.lastUndoDescription, equals('Action 2'));
    });
  });
}
