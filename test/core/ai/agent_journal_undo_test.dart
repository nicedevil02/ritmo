import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_journal.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class _FakeJournalDb implements Database {
  final List<Map<String, Object?>> journalRows = [];

  @override
  bool get isOpen => true;

  @override
  Future<void> close() async {}

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {}

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    journalRows.add(Map<String, Object?>.from(values));
    return journalRows.length;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    var result = List<Map<String, Object?>>.from(journalRows);
    if (where != null &&
        where.contains('id = ?') &&
        whereArgs != null &&
        whereArgs.isNotEmpty) {
      final targetId = whereArgs.first.toString();
      result = result.where((r) => r['id'] == targetId).toList();
    }
    if (where != null && where.contains('isSuccess = 1 AND undoneAt IS NULL')) {
      result = result
          .where(
            (r) =>
                r['isSuccess'] == 1 &&
                r['undoneAt'] == null &&
                r['undoKind'] != null,
          )
          .toList();
    }
    if (limit != null && result.length > limit) {
      result = result.take(limit).toList();
    }
    return result;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    var count = 0;
    if (where != null &&
        where.contains('id = ?') &&
        whereArgs != null &&
        whereArgs.isNotEmpty) {
      final targetId = whereArgs.first.toString();
      for (var row in journalRows) {
        if (row['id'] == targetId) {
          row.addAll(values);
          count++;
        }
      }
    }
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DummyWriteTool extends AgentTool {
  const _DummyWriteTool()
    : super(
        name: 'dummy_write',
        categoryFa: 'تست',
        titleFa: 'ابزار تغییر آزمایشی',
        descriptionFa: 'برای ژورنال',
        policy: ToolPolicy.actionDirect,
      );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    return AgentToolResult.success(
      toolName: name,
      data: {},
      summaryFa: 'انجام شد',
    );
  }
}

class _DummyReadTool extends AgentTool {
  const _DummyReadTool()
    : super(
        name: 'dummy_read',
        categoryFa: 'تست',
        titleFa: 'ابزار خواندنی',
        descriptionFa: 'برای ژورنال',
        policy: ToolPolicy.readOnly,
      );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    return AgentToolResult.success(
      toolName: name,
      data: {},
      summaryFa: 'خوانده شد',
    );
  }
}

void main() {
  group('AgentJournal Tests (T50)', () {
    late _FakeJournalDb fakeDb;

    setUp(() {
      fakeDb = _FakeJournalDb();
      DatabaseHelper.databaseInstance = fakeDb;
    });

    tearDown(() {
      DatabaseHelper.databaseInstance = null;
    });

    test('ignores readOnly tools during record', () async {
      const readTool = _DummyReadTool();
      final id = await AgentJournal.instance.record(
        sessionId: 's1',
        tool: readTool,
        args: {},
        result: AgentToolResult.success(
          toolName: readTool.name,
          data: {},
          summaryFa: 'خوانده شد',
        ),
      );
      expect(id, isNull);
      expect(fakeDb.journalRows, isEmpty);
    });

    test('records actionDirect tool executions in journal', () async {
      const writeTool = _DummyWriteTool();
      final id = await AgentJournal.instance.record(
        sessionId: 's1',
        tool: writeTool,
        args: {'title': 'روتین تست'},
        result: AgentToolResult.success(
          toolName: writeTool.name,
          data: {'isUndoable': true, 'planId': 'p123'},
          summaryFa: 'روتین اضافه شد',
        ),
      );

      expect(id, isNotNull);
      expect(fakeDb.journalRows.length, 1);
      final entry = fakeDb.journalRows.first;
      expect(entry['toolName'], 'dummy_write');
      expect(entry['undoKind'], 'plan');
      expect(entry['undoRef'], 'p123');
      expect(entry['isSuccess'], 1);
      expect(entry['undoneAt'], isNull);
    });

    test('retrieves recent journal entries and filters correctly', () async {
      const writeTool = _DummyWriteTool();
      await AgentJournal.instance.record(
        sessionId: 's1',
        tool: writeTool,
        args: {'title': 'روتین ۱'},
        result: AgentToolResult.success(
          toolName: writeTool.name,
          data: {'isUndoable': true, 'planId': 'p1'},
          summaryFa: 'ثبت ۱',
        ),
      );

      final list = await AgentJournal.instance.recent();
      expect(list.length, 1);
      expect(list.first.canUndo, isTrue);
      expect(list.first.isUndone, isFalse);

      final count = await AgentJournal.instance.undoableCount();
      expect(count, 1);
    });
  });
}
