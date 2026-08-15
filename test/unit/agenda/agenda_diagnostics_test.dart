import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/calendar/presentation/widgets/agenda_diagnostics_sheet.dart';
import 'package:sqflite/sqflite.dart';

class _FakeDatabase implements Database {
  @override
  bool get isOpen => true;
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
    return [];
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    if (sql.contains('COUNT(*)')) {
      return [
        {'COUNT(*)': 0}
      ];
    }
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase M3-D: Agenda Diagnostics Observability (P14 / M3-5)', () {
    test('M3-5: collectAgendaDiagnostics runs and outputs per-source breakdown', () async {
      final fakeDb = _FakeDatabase();
      DatabaseHelper.databaseInstance = fakeDb;

      final report = await collectAgendaDiagnostics(targetDate: DateTime(2026, 8, 15));

      expect(report, contains('RITMO AGENDA DIAGNOSTICS'));
      expect(report, contains('Per-Source Agenda Metrics'));
      expect(report, contains('registered sources'));
      expect(report, contains('DayAgendaService Pipeline'));
      expect(report, contains('VERDICT'));
    });
  });
}
