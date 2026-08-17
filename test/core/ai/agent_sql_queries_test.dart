import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/catalog/notes_agent_tools.dart';
import 'package:ritmo/core/ai/agent/catalog/wellbeing_agent_tools.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class _CapturingMockDatabase implements Database {
  final List<String> executedSql = [];
  final List<List<Object?>?> executedArgs = [];

  @override
  bool get isOpen => true;

  @override
  Future<void> close() async {}

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    executedSql.add(sql);
    executedArgs.add(arguments);

    if (sql.contains('notes')) {
      return [
        {
          'id': 'n1',
          'title': 'یادداشت اول',
          'content': 'محتوا',
          'tags': 'ورزش',
          'updatedAt': '2026-08-17',
        }
      ];
    }
    if (sql.contains('bedtime_diagnostics')) {
      return [
        {
          'date': '2026-08-17',
          'durationMinutes': 480,
          'quality': 'عالی',
          'createdAt': '2026-08-17T08:00:00',
        }
      ];
    }
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Agent Tool SQL Query Sanitization & Parameterization Tests (T44)', () {
    late _CapturingMockDatabase mockDb;

    setUp(() {
      mockDb = _CapturingMockDatabase();
      DatabaseHelper.databaseInstance = mockDb;
    });

    tearDown(() {
      DatabaseHelper.databaseInstance = null;
    });

    test('SearchUserNotesTool executes with parameterized arguments and never injects raw string in SQL', () async {
      const tool = SearchUserNotesTool();
      final res = await tool.execute({'query': "test' OR '1'='1"});
      expect(res.isSuccess, isTrue);

      expect(mockDb.executedSql.isNotEmpty, isTrue);
      final lastSql = mockDb.executedSql.last;
      expect(lastSql, contains('WHERE title LIKE ? OR content LIKE ? OR tags LIKE ?'));
      expect(lastSql.contains("test' OR '1'='1"), isFalse);

      final lastArgs = mockDb.executedArgs.last;
      expect(lastArgs, isNotNull);
      expect(lastArgs, contains("%test' OR '1'='1%"));
    });

    test('GetSleepDiagnosticsTool binds LIMIT using parameterized placeholder', () async {
      const tool = GetSleepDiagnosticsTool();
      final res = await tool.execute({'days': 7});
      expect(res.isSuccess, isTrue);

      expect(mockDb.executedSql.isNotEmpty, isTrue);
      final lastSql = mockDb.executedSql.last;
      expect(lastSql, contains('LIMIT ?'));

      final lastArgs = mockDb.executedArgs.last;
      expect(lastArgs, isNotNull);
      expect(lastArgs, [7]);
    });
  });
}
