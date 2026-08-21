import 'package:ritmo/core/logging/ritmo_logger.dart';

/// An abstract command that can be executed and undone.
abstract class UndoableCommand {
  Future<void> execute();
  Future<void> undo();
  String get description;
}

/// A lightweight stack managing undoable operations and redo history for calendar and domain actions.
class CommandStack {
  CommandStack._();
  static final CommandStack instance = CommandStack._();

  static const int maxStackDepth = 50;
  final List<UndoableCommand> _undoStack = [];
  final List<UndoableCommand> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  int get length => _undoStack.length;
  String? get lastUndoDescription =>
      _undoStack.isNotEmpty ? _undoStack.last.description : null;
  String? get lastRedoDescription =>
      _redoStack.isNotEmpty ? _redoStack.last.description : null;

  void push(UndoableCommand command) {
    _undoStack.add(command);
    if (_undoStack.length > maxStackDepth) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear(); // Pushing a new command invalidates redo history
  }

  Future<bool> undoLast() async {
    if (_undoStack.isEmpty) return false;
    final command = _undoStack.removeLast();
    try {
      await command.undo();
      _redoStack.add(command);
      if (_redoStack.length > maxStackDepth) {
        _redoStack.removeAt(0);
      }
      return true;
    } catch (e, st) {
      RitmoLog.error(
        'CommandStack',
        'Error undoing command "${command.description}"',
        e,
        st,
      );
      return false;
    }
  }

  Future<bool> redoLast() async {
    if (_redoStack.isEmpty) return false;
    final command = _redoStack.removeLast();
    try {
      await command.execute();
      _undoStack.add(command);
      if (_undoStack.length > maxStackDepth) {
        _undoStack.removeAt(0);
      }
      return true;
    } catch (e, st) {
      RitmoLog.error(
        'CommandStack',
        'Error redoing command "${command.description}"',
        e,
        st,
      );
      return false;
    }
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
