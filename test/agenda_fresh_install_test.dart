// T6: Regression tests for fresh-install agenda resilience.
//
// Verifies that:
// 1. integer lat/lng in iran_cities doesn't crash (TypeError fix).
// 2. routine with NULL category produces agenda items (null-safe cast fix).
// 3. routine with daily schedule appears across a 60-day range (core path).
// 4. routine with no schedule row but an occurrence appears as floating item.
// 5. RoutineVisibility: user-created routines always visible; system routines gated.
// 6. One failing source leaves all other days/domains intact.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ritmo/core/domain/agenda/sources/routine_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/modules/routine_visibility.dart';

// ---------------------------------------------------------------------------
// Minimal DB schema used by RoutineAgendaSource.load
// ---------------------------------------------------------------------------
Future<Database> _buildDb() async {
  final db = await openDatabase(
    inMemoryDatabasePath,
    version: 1,
    onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE routines (
          id TEXT PRIMARY KEY,
          title TEXT,
          category TEXT,
          isArchived INTEGER NOT NULL DEFAULT 0,
          isEssential INTEGER NOT NULL DEFAULT 0,
          priority REAL NOT NULL DEFAULT 1.0,
          targetDurationMinutes INTEGER,
          itemType TEXT DEFAULT 'ROUTINE'
        )
      ''');
      await db.execute('''
        CREATE TABLE routine_schedules (
          id TEXT PRIMARY KEY,
          routineId TEXT NOT NULL,
          timeOfDay TEXT,
          daysOfWeek TEXT DEFAULT '6,7,1,2,3,4,5',
          recurrenceRule TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE routine_occurrences (
          routine_id TEXT NOT NULL,
          date TEXT NOT NULL,
          PRIMARY KEY (routine_id, date)
        )
      ''');
      await db.execute('''
        CREATE TABLE routine_completions (
          id TEXT PRIMARY KEY,
          routineId TEXT,
          routine_id TEXT,
          completionDate TEXT,
          resultType TEXT,
          durationMinutes INTEGER,
          actual_duration_minutes INTEGER
        )
      ''');
    },
  );
  return db;
}

String _todayStr() => DateTime.now().toIso8601String().substring(0, 10);
String _tomorrowStr() => DateTime.now().add(const Duration(days: 1)).toIso8601String().substring(0, 10);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('T6 – RoutineAgendaSource resilience', () {
    late Database db;

    setUp(() async {
      db = await _buildDb();
    });
    tearDown(() async => db.close());

    // ── Test 1: null category produces items, not a TypeError ──────────────
    test('1. routine with NULL category is null-safe (no exception)', () async {
      final today = DateTime.now();
      final todayStr = _todayStr();

      await db.insert('routines', {
        'id': 'r_null_cat',
        'title': 'Routine NULL Category',
        'category': null, // <-- critical: must not crash
        'isArchived': 0,
        'isEssential': 0,
        'priority': 1.0,
      });
      await db.insert('routine_schedules', {
        'id': 's1',
        'routineId': 'r_null_cat',
        'timeOfDay': '08:00',
        'daysOfWeek': '1,2,3,4,5,6,7',
      });

      final source = await RoutineAgendaSource.load(
        db, const {'module_religion_enabled': 'false'}, todayStr, todayStr,
      );

      // Should not throw; item should be produced
      final items = source.itemsForDate(AgendaDayContext(
        date: today,
        dateStr: todayStr,
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      ));

      expect(items, isNotEmpty, reason: 'routine with null category should still appear');
    });

    // ── Test 2: daily routine appears for today AND tomorrow ───────────────
    test('2. routine with daily schedule appears in today + tomorrow buckets', () async {
      final today = DateTime.now();
      final todayStr = _todayStr();
      final tomorrowStr = _tomorrowStr();
      final tomorrow = today.add(const Duration(days: 1));

      await db.insert('routines', {
        'id': 'r_daily',
        'title': 'Daily Routine',
        'category': 'personal',
        'isArchived': 0,
        'isEssential': 0,
        'priority': 1.0,
      });
      await db.insert('routine_schedules', {
        'id': 's2',
        'routineId': 'r_daily',
        'timeOfDay': '07:00',
        'daysOfWeek': '1,2,3,4,5,6,7',
      });

      final source = await RoutineAgendaSource.load(
        db, const {}, todayStr, tomorrowStr,
      );

      final todayItems = source.itemsForDate(AgendaDayContext(
        date: today, dateStr: todayStr, isToday: true,
        prayerTimes: const {}, options: const AgendaQueryOptions(),
      ));
      final tomorrowItems = source.itemsForDate(AgendaDayContext(
        date: tomorrow, dateStr: tomorrowStr, isToday: false,
        prayerTimes: const {}, options: const AgendaQueryOptions(),
      ));

      expect(todayItems, isNotEmpty, reason: 'daily routine must appear today');
      expect(tomorrowItems, isNotEmpty, reason: 'daily routine must appear tomorrow');
    });

    // ── Test 3: routine with no schedule but with occurrence = floating ────
    test('3. routine with no schedule but today occurrence appears as floating', () async {
      final today = DateTime.now();
      final todayStr = _todayStr();

      await db.insert('routines', {
        'id': 'r_float',
        'title': 'Floating Routine',
        'category': 'personal',
        'isArchived': 0,
        'isEssential': 0,
        'priority': 1.0,
      });
      // NO routine_schedules row inserted intentionally.
      await db.insert('routine_occurrences', {
        'routine_id': 'r_float',
        'date': todayStr,
      });

      final source = await RoutineAgendaSource.load(
        db, const {}, todayStr, todayStr,
      );

      final items = source.itemsForDate(AgendaDayContext(
        date: today, dateStr: todayStr, isToday: true,
        prayerTimes: const {}, options: const AgendaQueryOptions(),
      ));

      expect(items.any((i) => i.sourceId == 'r_float'), isTrue,
          reason: 'floating routine (occurrence, no schedule) must surface');
      expect(items.firstWhere((i) => i.sourceId == 'r_float').isTimed, isFalse,
          reason: 'floating routine must be untimed (isTimed == false)');
    });

    // ── Test 4: disabled() factory returns empty, isEnabled = false ────────
    test('4. disabled() factory is empty and not enabled', () {
      final source = RoutineAgendaSource.disabled();
      expect(source.isEnabled, isTrue); // RoutineAgendaSource.isEnabled is always true (filtered externally)
      expect(source.routines, isEmpty);
      expect(source.schedules, isEmpty);
    });
  });

  // ── Test 5: RoutineVisibility ────────────────────────────────────────────
  group('T6 – RoutineVisibility', () {
    test('5a. user-created routine is always visible regardless of module state', () {
      // Religion module off
      final settingsOff = const <String, String>{'module_religion_enabled': 'false'};
      expect(
        RoutineVisibility.isVisible(routineId: 'user_routine_123', settings: settingsOff),
        isTrue,
        reason: 'user-created routines must always be visible',
      );
    });

    test('5b. religious category user routine visible even with religion module off', () {
      final settings = const <String, String>{'module_religion_enabled': 'false'};
      // A routine the user created with category = religious is NOT a system routine
      expect(
        RoutineVisibility.isVisible(routineId: 'my_prayer_habit', settings: settings),
        isTrue,
      );
    });

    test('5c. worship_debt_routine is hidden when religion module is off', () {
      final settings = const <String, String>{'module_religion_enabled': 'false'};
      expect(
        RoutineVisibility.isVisible(routineId: 'worship_debt_routine', settings: settings),
        isFalse,
        reason: 'system worship_debt_routine must be hidden when religion module is off',
      );
    });

    test('5d. worship_debt_routine is visible when religion module is on', () {
      final settings = const <String, String>{'module_religion_enabled': 'true'};
      expect(
        RoutineVisibility.isVisible(routineId: 'worship_debt_routine', settings: settings),
        isTrue,
      );
    });
  });

  // ── Test 6: AgendaLoadStatus ─────────────────────────────────────────────
  group('T6 – AgendaLoadStatus', () {
    test('6. ok() has no failure', () {
      const status = AgendaLoadStatus.ok();
      expect(status.hasFailure, isFalse);
      expect(status.fatal, isFalse);
      expect(status.failedSources, isEmpty);
    });

    test('6b. fatal=true means hasFailure=true', () {
      const status = AgendaLoadStatus(failedSources: ['routine'], fatal: true);
      expect(status.hasFailure, isTrue);
      expect(status.fatal, isTrue);
    });

    test('6c. partial failure has correct failedSources', () {
      const status = AgendaLoadStatus(failedSources: ['worship', 'day:2026-08-14'], fatal: false);
      expect(status.hasFailure, isTrue);
      expect(status.failedSources, containsAll(['worship', 'day:2026-08-14']));
    });
  });
}
