import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/onboarding/logic/onboarding_controller.dart';
import 'package:ritmo/features/onboarding/logic/onboarding_gate.dart';
import 'package:ritmo/features/onboarding/logic/starter_pack_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class MockDatabase implements Database {
  @override
  bool get isOpen => true;

  final Map<String, List<Map<String, dynamic>>> tables = {};

  @override
  Batch batch() => MockBatch(this);

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action, {bool? exclusive}) async {
    final mockTxn = MockTransaction(this);
    return action(mockTxn);
  }

  @override
  Future<int> insert(String table, Map<String, Object?> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async {
    final list = tables.putIfAbsent(table, () => []);
    if (conflictAlgorithm == ConflictAlgorithm.replace && values.containsKey('key')) {
      list.removeWhere((r) => r['key'] == values['key']);
    } else if (conflictAlgorithm == ConflictAlgorithm.replace && values.containsKey('id')) {
      list.removeWhere((r) => r['id'] == values['id']);
    }
    list.add(Map<String, dynamic>.from(values));
    return 1;
  }

  @override
  Future<int> update(String table, Map<String, Object?> values, {String? where, List<Object?>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) async {
    final list = tables[table] ?? [];
    var count = 0;
    for (var i = 0; i < list.length; i++) {
      final updatedRow = Map<String, dynamic>.from(list[i])..addAll(values);
      list[i] = updatedRow;
      count++;
    }
    return count;
  }

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    final list = tables[table] ?? [];
    final beforeLength = list.length;
    list.clear();
    return beforeLength;
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
    final list = tables[table] ?? [];
    if (where != null && where.contains('key =')) {
      final key = whereArgs?.isNotEmpty == true ? whereArgs![0] : 'onboarding_completed';
      return list.where((r) => r['key'] == key).toList();
    }
    if (where != null && where.contains('id =')) {
      final id = whereArgs?.isNotEmpty == true ? whereArgs![0] : null;
      return list.where((r) => r['id'] == id).toList();
    }
    return list;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockTransaction implements Transaction {
  MockTransaction(this.db);
  final MockDatabase db;

  bool get isOpen => db.isOpen;

  @override
  Batch batch() => MockBatch(db);

  @override
  Future<int> insert(String table, Map<String, Object?> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) {
    return db.insert(table, values, nullColumnHack: nullColumnHack, conflictAlgorithm: conflictAlgorithm);
  }

  @override
  Future<int> update(String table, Map<String, Object?> values, {String? where, List<Object?>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) {
    return db.update(table, values, where: where, whereArgs: whereArgs, conflictAlgorithm: conflictAlgorithm);
  }

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) {
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  @override
  Future<List<Map<String, Object?>>> query(String table, {bool? distinct, List<String>? columns, String? where, List<Object?>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset}) {
    return db.query(table, distinct: distinct, columns: columns, where: where, whereArgs: whereArgs, groupBy: groupBy, having: having, orderBy: orderBy, limit: limit, offset: offset);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockBatch implements Batch {
  MockBatch(this.db);
  final MockDatabase db;

  @override
  void insert(String table, Map<String, Object?> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) {
    db.insert(table, values, nullColumnHack: nullColumnHack, conflictAlgorithm: conflictAlgorithm);
  }

  @override
  void rawInsert(String sql, [List<Object?>? arguments]) {
    if (sql.contains('INSERT INTO routines') && arguments != null) {
      db.insert('routines', {
        'id': arguments[0],
        'title': arguments[1],
        'category': arguments[2],
        'routineType': arguments[3],
        'notificationLevel': arguments[4],
        'isEssential': arguments[5],
        'energyRule': arguments[6],
        'priority': arguments[7],
        'targetDurationMinutes': arguments[8],
        'displayOrder': arguments[9],
        'description': arguments[10],
        'createdAt': arguments[11],
        'updatedAt': arguments[12],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else if (sql.contains('INSERT INTO routine_schedules') && arguments != null) {
      db.insert('routine_schedules', {
        'id': arguments[0],
        'routineId': arguments[1],
        'scheduleType': arguments[2],
        'timeOfDay': arguments[3],
        'daysOfWeek': arguments[4],
        'recurrenceRule': arguments[5],
        'createdAt': arguments[6],
        'updatedAt': arguments[7],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else if (sql.contains('INSERT INTO app_settings') && arguments != null) {
      db.insert('app_settings', {
        'key': arguments[0],
        'value': arguments[1],
        'updatedAt': arguments[2],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  @override
  Future<List<Object?>> commit({bool? exclusive, bool? noResult, bool? continueOnError}) async {
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('B0-3 & B0-4: Onboarding Idempotency & Gate Healing', () {
    test('OnboardingController creates starter routines with energyRule NONE and avoids duplicate rows on second run', () async {
      SharedPreferences.setMockInitialValues({});
      final mockDb = MockDatabase();
      DatabaseHelper.instance.overrideDatabaseForTesting(mockDb);

      final controller = OnboardingController();
      controller.userName = 'کاربر آزمایشی';
      final templates = StarterPackCatalog.suggestFor(controller.focusAreas);
      controller.selectedStarterRoutines = templates;

      var finishedCalled = false;
      await controller.save(onFinished: () {
        finishedCalled = true;
      });

      expect(finishedCalled, isTrue);

      final routines = await mockDb.query('routines');
      expect(routines.length, equals(templates.length));
      for (final r in routines) {
        expect(r['energyRule'], equals('NONE'));
      }

      // Run save again with same controller & routines to verify idempotency (should not duplicate or error)
      var secondFinished = false;
      await controller.save(onFinished: () {
        secondFinished = true;
      });

      expect(secondFinished, isTrue);
      final routinesAfterSecond = await mockDb.query('routines');
      expect(routinesAfterSecond.length, equals(templates.length));
    });

    test('OnboardingGate.isCompleted is read-only and healFromPrefs heals SQLite', () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': true,
        'user_name': 'رضا',
      });

      final mockDb = MockDatabase();

      // isCompleted returns true because SharedPreferences has completed state, but it doesn't write to DB
      final completed = await OnboardingGate.isCompleted(mockDb);
      expect(completed, isTrue);

      final dbRowsBeforeHeal = await mockDb.query('app_settings', where: "key = 'onboarding_completed'");
      expect(dbRowsBeforeHeal.isEmpty, isTrue);

      // Explicitly heal
      final healed = await OnboardingGate.healFromPrefs(mockDb);
      expect(healed, isTrue);

      final dbRowsAfterHeal = await mockDb.query('app_settings', where: "key = 'onboarding_completed'");
      expect(dbRowsAfterHeal.length, equals(1));
      expect(dbRowsAfterHeal.first['value'], equals('true'));
    });
  });
}
