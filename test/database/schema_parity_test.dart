import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/migration/migration_runner.dart';
import 'package:ritmo/core/database/schema/tables/ai_tables.dart';
import 'package:ritmo/core/database/schema/tables/assistant_tables.dart';
import 'package:ritmo/core/database/schema/tables/course_tables.dart';
import 'package:ritmo/core/database/schema/tables/cycle_tables.dart';
import 'package:ritmo/core/database/schema/tables/day_plan_tables.dart';
import 'package:ritmo/core/database/schema/tables/goal_tables.dart';
import 'package:ritmo/core/database/schema/tables/health_tables.dart';
import 'package:ritmo/core/database/schema/tables/konkur_tables.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/core/database/schema/tables/note_tables.dart';
import 'package:ritmo/core/database/schema/tables/routine_tables.dart';
import 'package:ritmo/core/database/schema/tables/sleep_tables.dart';
import 'package:ritmo/core/database/schema/tables/sports_tables.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/core/database/schema/tables/system_tables.dart';
import 'package:ritmo/core/database/schema/tables/worship_tables.dart';
import 'package:ritmo/core/database/schema/tables/zone_tables.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:sqflite/sqflite.dart';

class RecordingDatabase implements Database {
  final Map<String, Set<String>> tables;
  RecordingDatabase({Map<String, Set<String>>? tables}) : tables = tables ?? {};

  void _parseSql(String sql) {
    // Strip single line comments --
    final lines = sql.split('\n').map((l) {
      final commentIdx = l.indexOf('--');
      return commentIdx != -1 ? l.substring(0, commentIdx) : l;
    }).join(' ');

    final clean = lines.replaceAll('\r', ' ').trim();
    final lower = clean.toLowerCase();

    if (lower.startsWith('create table')) {
      final firstParen = clean.indexOf('(');
      if (firstParen != -1) {
        final tableHeader = clean.substring(0, firstParen).trim();
        final parts = tableHeader.split(RegExp(r'\s+'));
        final tableName = parts.last.replaceAll('`', '').replaceAll('"', '').replaceAll("'", '');
        
        final body = clean.substring(firstParen + 1, clean.lastIndexOf(')') != -1 ? clean.lastIndexOf(')') : clean.length);
        final colDefs = body.split(',');
        final cols = <String>{};
        for (var colDef in colDefs) {
          colDef = colDef.trim();
          final colLower = colDef.toLowerCase();
          if (colLower.startsWith('primary key') ||
              colLower.startsWith('foreign key') ||
              colLower.startsWith('unique') ||
              colLower.startsWith('constraint') ||
              colLower.startsWith('check')) {
            continue;
          }
          final tokens = colDef.split(RegExp(r'\s+'));
          if (tokens.isNotEmpty && tokens.first.isNotEmpty) {
            final colName = tokens.first.replaceAll('`', '').replaceAll('"', '').replaceAll("'", '').toLowerCase();
            cols.add(colName);
          }
        }
        tables[tableName.toLowerCase()] = cols;
      }
    } else if (lower.startsWith('alter table')) {
      final addIdx = lower.indexOf('add column');
      final renameIdx = lower.indexOf('rename to');
      if (addIdx != -1) {
        final tableIdx = lower.indexOf('alter table') + 'alter table'.length;
        final tableName = clean.substring(tableIdx, addIdx).trim().split(' ').first.replaceAll('`', '').replaceAll('"', '').replaceAll("'", '').toLowerCase();
        final colPart = clean.substring(addIdx + 'add column'.length).trim();
        final colName = colPart.split(' ').first.replaceAll('`', '').replaceAll('"', '').replaceAll("'", '').toLowerCase();
        tables.putIfAbsent(tableName, () => {}).add(colName);
      } else if (renameIdx != -1) {
        final tableIdx = lower.indexOf('alter table') + 'alter table'.length;
        final oldTableName = clean.substring(tableIdx, renameIdx).trim().split(' ').first.replaceAll('`', '').replaceAll('"', '').replaceAll("'", '').replaceAll(';', '').toLowerCase();
        final newTableName = clean.substring(renameIdx + 'rename to'.length).trim().split(' ').first.replaceAll('`', '').replaceAll('"', '').replaceAll("'", '').replaceAll(';', '').toLowerCase();
        if (tables.containsKey(oldTableName)) {
          tables[newTableName] = tables.remove(oldTableName)!;
        }
      }
    } else if (lower.startsWith('drop table')) {
      final parts = clean.split(RegExp(r'\s+'));
      final tableName = parts.last.replaceAll(';', '').replaceAll('`', '').replaceAll('"', '').replaceAll("'", '').toLowerCase();
      tables.remove(tableName);
    }
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    _parseSql(sql);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    final lower = sql.toLowerCase();
    if (lower.contains('pragma table_info')) {
      var tableName = '';
      if (sql.contains('(') && sql.contains(')')) {
        tableName = sql.substring(sql.indexOf('(') + 1, sql.indexOf(')')).replaceAll('`', '').replaceAll('"', '').replaceAll("'", '').trim().toLowerCase();
      } else {
        final parts = sql.trim().split(RegExp(r'\s+'));
        tableName = parts.last.replaceAll(';', '').replaceAll('`', '').replaceAll('"', '').replaceAll("'", '').toLowerCase();
      }
      final cols = tables[tableName] ?? {};
      return cols.map((c) => {'name': c}).toList();
    }
    return [];
  }

  @override
  Future<int> insert(String table, Map<String, Object?> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async {
    return 1;
  }

  @override
  Future<int> update(String table, Map<String, Object?> values, {String? where, List<Object?>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) async {
    return 1;
  }

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    return 0;
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async => 1;

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async => 1;

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async => 0;

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action, {bool? exclusive}) async {
    final fakeTxn = FakeTransaction(tables);
    return await action(fakeTxn);
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
    return [];
  }

  @override
  Batch batch() => FakeBatch(this);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTransaction extends RecordingDatabase implements Transaction {
  FakeTransaction(Map<String, Set<String>> tables) : super(tables: tables);
}

class FakeBatch implements Batch {
  final RecordingDatabase db;
  FakeBatch(this.db);

  @override
  void execute(String sql, [List<Object?>? arguments]) {
    db._parseSql(sql);
  }

  @override
  void insert(String table, Map<String, Object?> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) {}

  @override
  void update(String table, Map<String, Object?> values, {String? where, List<Object?>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) {}

  @override
  void delete(String table, {String? where, List<Object?>? whereArgs}) {}

  @override
  void rawInsert(String sql, [List<Object?>? arguments]) {}

  @override
  void rawUpdate(String sql, [List<Object?>? arguments]) {}

  @override
  void rawDelete(String sql, [List<Object?>? arguments]) {}

  @override
  Future<List<Object?>> commit({bool? exclusive, bool? noResult, bool? continueOnError}) async {
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _createV1Tables(Database db) async {
  await RoutineTables.create(db);
  await WorshipTables.create(db);
  await HealthTables.create(db);
  await CourseTables.create(db);
  await GoalTables.create(db);
  await ZoneTables.create(db);
  await CycleTables.create(db);
  await KonkurTables.create(db);
  await SportsTables.create(db);
  await SystemTables.create(db);
  await SupplementarySportsTables.create(db);
  await AssistantTables.create(db);
  await AiTables.create(db);
  await DayPlanTables.create(db);
  await NoteTables.create(db);
  await SleepTables.create(db);
  await MovementTables.create(db);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DB-10: fresh install schema == migrated schema (Schema Parity Audit)', () async {
    final freshDb = RecordingDatabase();
    await SchemaManager.createAll(freshDb);

    final migratedDb = RecordingDatabase();
    await _createV1Tables(migratedDb);
    await MigrationRunner.run(migratedDb, 1, DatabaseHelper.dbVersionForTest);

    final freshTables = freshDb.tables;
    final migratedTables = migratedDb.tables;

    final freshKeys = freshTables.keys.toSet();
    final migratedKeys = migratedTables.keys.toSet();

    final missingInMigrated = freshKeys.difference(migratedKeys);
    expect(missingInMigrated, isEmpty, reason: 'Tables present in fresh install but missing in migrated DB: $missingInMigrated');

    for (final table in freshKeys) {
      final freshCols = freshTables[table]!;
      final migratedCols = migratedTables[table];
      expect(migratedCols, isNotNull, reason: 'Table $table missing in migrated DB');

      final missingCols = freshCols.difference(migratedCols!);
      expect(missingCols, isEmpty, reason: 'Table $table columns missing in migrated DB: $missingCols');
    }
  });
}
