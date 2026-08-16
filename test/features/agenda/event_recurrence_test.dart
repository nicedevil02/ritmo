import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/routines/domain/strategies/generic_strategy.dart';
import 'package:ritmo/features/routines/domain/strategies/planner_save_context.dart';
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
    if (where != null && where == "itemType = 'EVENT'") {
      return list.where((r) => r['itemType'] == 'EVENT').toList();
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
    db.insert(table, values);
  }

  @override
  Future<List<Object?>> commit({bool? exclusive, bool? noResult, bool? continueOnError}) async {
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Builds the exact payload the planner hands to [GenericStrategy] for an
/// event.
///
/// [recurrenceType] is injectable so a test can reproduce the real
/// `PlannerController` default instead of an idealised value.
///
/// [selectedDate] and [eventDate] are injectable *separately* on purpose. The
/// original fixture set both to the same day, which made them
/// indistinguishable — and that is precisely why the date-override defect
/// stayed green for so long. In the real app `selectedDate` carries the day the
/// user picked in `PlannerTimelinePicker`, while `eventDate` keeps its
/// untouched `DateTime.now()` default from the controller.
PlannerSaveContext buildEventContext({
  required String recurrenceType,
  DateTime? selectedDate,
}) {
  final pickedDate = selectedDate ?? DateTime(2026, 8, 20);
  return PlannerSaveContext(
    title: 'جلسه کاری مهم',
    description: 'توضیحات جلسه',
    notes: '',
    selectedDate: pickedDate,
    selectedTime: const TimeOfDay(hour: 14, minute: 0),
    isEditing: false,
    routineToEdit: null,
    selectedCategory: Category.work,
    itemType: 'EVENT',
    recurrenceType: recurrenceType,
    targetDuration: 60,
    reminderOffsetMinutes: 15,
    priority: 2.0,
    energyRule: 'NONE',
    dependsOnRoutineId: null,
    selectedZoneId: null,
    worshipType: 'MUSTAHAB',
    worshipDebtType: 'PRAYER',
    worshipTotalCount: 0,
    worshipDailyTarget: 0,
    worshipReminderAnchor: 'NONE',
    worshipOffsetMinutes: 0,
    // پیش‌فرض واقعی PlannerController: هر هفت روز هفته انتخاب شده است.
    worshipSelectedDays: const [6, 7, 1, 2, 3, 4, 5],
    worshipRepeatType: 'RECURRING',
    sportsOpType: 'ROUTINE',
    sportsType: 'RUNNING',
    sportsDuration: 30,
    sportsIntensity: 'MEDIUM',
    sportsLocation: 'HOME',
    sportsFeeling: 'GOOD',
    medicalMode: 'FIXED',
    medicalTimes: const [],
    medicalStockCount: 0,
    medicalRefillWarning: 0,
    medicalMinIntervalHours: 0,
    medicalMaxDosesPerDay: 0,
    courseType: 'VIDEO',
    courseTotalSessions: 0,
    courseWeeklyTarget: 0,
    courseSessionDuration: 0,
    coursePreferredDays: const [],
    coursePreferredTime: const TimeOfDay(hour: 8, minute: 0),
    goalType: 'DAILY',
    goalTargetDate: DateTime.now(),
    goalSteps: const [],
    reflectionMood: 3,
    reflectionWins: '',
    reflectionGratitude: '',
    reflectionLearnings: '',
    reflectionIsPrivate: false,
    // B-FIX-EVENT-5: eventDate, eventStartTime, eventEndTime, eventLocation removed
  );
}

Future<void> saveThroughStrategy(WidgetTester tester, PlannerSaveContext ctx) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              const strategy = GenericStrategy();
              await strategy.save(ctx, context);
            },
            child: const Text('Save Event'),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('Save Event'));
  await tester.pumpAndSettle();
}

void main() {
  group('B0-2: Event Recurrence & Duration Bounds', () {
    testWidgets('GenericStrategy persists EVENT with OnceRecurrence', (tester) async {
      final mockDb = MockDatabase();
      DatabaseHelper.instance.overrideDatabaseForTesting(mockDb);

      await saveThroughStrategy(tester, buildEventContext(recurrenceType: 'ONCE'));

      final routines = await mockDb.query('routines', where: "itemType = 'EVENT'");
      expect(routines.length, equals(1));
      final r = routines.first;
      expect(r['title'], equals('جلسه کاری مهم'));
      expect(r['targetDurationMinutes'], equals(60)); // B-FIX-EVENT-5: canonical targetDuration

      final schedules = await mockDb.query('routine_schedules');
      expect(schedules.length, equals(1));
      final s = schedules.first;
      expect(s['timeOfDay'], equals('14:00'));
      expect(s['scheduleType'], equals('ONCE'));

      final rule = RecurrenceRule.fromMap(jsonDecode(s['recurrenceRule'] as String));
      expect(rule.startDate, isNotNull);
      expect(rule.startDate!.year, equals(2026));
      expect(rule.startDate!.month, equals(8));
      expect(rule.startDate!.day, equals(20));
    });

    // REGRESSION GUARD — مسیر واقعی نوشتن رویداد.
    testWidgets('EVENT stays one-shot even with the real EVERY_DAY controller default', (tester) async {
      final mockDb = MockDatabase();
      DatabaseHelper.instance.overrideDatabaseForTesting(mockDb);

      await saveThroughStrategy(tester, buildEventContext(recurrenceType: 'EVERY_DAY'));

      final schedules = await mockDb.query('routine_schedules');
      expect(schedules.length, equals(1));
      final s = schedules.first;

      // اگر این سه ادعا بشکند، رویداد دوباره به روتین روزانه تبدیل شده است.
      expect(s['scheduleType'], equals('ONCE'));
      expect(s['daysOfWeek'], equals(''));

      final rule = RecurrenceRule.fromMap(jsonDecode(s['recurrenceRule'] as String));
      expect(rule.weekdays, isEmpty);
      expect(rule.startDate, isNotNull);
      expect(rule.endDate, isNotNull);
      expect(rule.startDate!.day, equals(20));
      expect(rule.endDate!.day, equals(20));
      expect(rule.endDate!.month, equals(8));
      expect(rule.endDate!.year, equals(2026));
    });
  });
}
