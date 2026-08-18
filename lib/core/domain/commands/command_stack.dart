import 'package:ritmo/core/logging/ritmo_logger.dart';

/// An abstract command that can be executed and undone.
abstract class UndoableCommand {
  Future<void> execute();
  Future<void> undo();
  String get description;
}

/// A lightweight stack managing undoable operations for calendar and domain actions.
class CommandStack {
  CommandStack._();
  static final CommandStack instance = CommandStack._();

  static const int maxStackDepth = 50;
  final List<UndoableCommand> _undoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  int get length => _undoStack.length;

  void push(UndoableCommand command) {
    _undoStack.add(command);
    if (_undoStack.length > maxStackDepth) {
      _undoStack.removeAt(0);
    }
  }

  Future<bool> undoLast() async {
    if (_undoStack.isEmpty) return false;
    final command = _undoStack.removeLast();
    try {
      await command.undo();
      return true;
    } catch (e, st) {
      RitmoLog.error('CommandStack', 'Error undoing command "${command.description}"', e, st);
      return false;
    }
  }

  void clear() {
    _undoStack.clear();
  }
}
