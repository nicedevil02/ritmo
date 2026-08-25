import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/worship/domain/prayer_log_quality.dart';
import 'package:ritmo/features/worship/logic/fadhilat.dart' as fadhilat;
import 'package:ritmo/features/worship/logic/hijri_calendar.dart';
import 'package:ritmo/features/worship/logic/prayer_timeline.dart';
import 'package:ritmo/features/worship/logic/prayer_times.dart';
import 'package:ritmo/features/worship/logic/worship_calendar_logic.dart';
import 'package:ritmo/features/worship/logic/worship_completion_repository.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class _FakeWorshipDatabase implements Database {
  @override
  bool get isOpen => true;

  final Map<String, List<Map<String, dynamic>>> tables = {
    'worship_practices': [
      {'id': 'wp_fajr', 'practiceType': 'PRAYER', 'subType': 'FAJR', 'title': 'نماز صبح', 'dailyTarget': 1, 'isActive': 1, 'sortOrder': 1},
      {'id': 'wp_dhuhr', 'practiceType': 'PRAYER', 'subType': 'DHUHR', 'title': 'نماز ظهر و عصر', 'dailyTarget': 1, 'isActive': 1, 'sortOrder': 2},
      {'id': 'wp_maghrib', 'practiceType': 'PRAYER', 'subType': 'MAGHRIB', 'title': 'نماز مغرب و عشا', 'dailyTarget': 1, 'isActive': 1, 'sortOrder': 4},
      {'id': 'wp_asr', 'practiceType': 'PRAYER', 'subType': 'ASR', 'title': 'نماز عصر', 'dailyTarget': 1, 'isActive': 0, 'sortOrder': 3},
      {'id': 'wp_isha', 'practiceType': 'PRAYER', 'subType': 'ISHA', 'title': 'نماز عشا', 'dailyTarget': 1, 'isActive': 0, 'sortOrder': 5},
    ],
    'app_settings': [
      {'key': 'prayer_city_id', 'value': 'TEHRAN_TEHRAN'},
      {'key': 'prayer_calculation_method', 'value': 'TEHRAN_GEOPHYSICS'},
      {'key': 'show_asr_isha_prayers', 'value': 'false'},
      {'key': 'hijri_offset', 'value': '0'},
    ],
    'worship_day_context': [],
    'worship_debts': [],
    'worship_completions': [],
    'worship_seasons': [],
    'prayer_times_cache': [],
    'routines': [],
    'simple_tasks': [],
  };

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {}

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action, {bool? exclusive}) async {
    return action(_FakeTransaction(this) as Transaction);
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    tables[table] ??= [];
    final row = Map<String, dynamic>.from(values);
    if (conflictAlgorithm == ConflictAlgorithm.replace) {
      if (table == 'worship_completions' || table == 'worship_debts' || table == 'app_settings' || table == 'worship_day_context') {
        final keyField = table == 'app_settings' ? 'key' : (table == 'worship_day_context' ? 'date' : 'id');
        tables[table]!.removeWhere((r) => r[keyField] == row[keyField]);
      } else if (table == 'prayer_times_cache') {
        tables[table]!.removeWhere((r) =>
            r['date'] == row['date'] &&
            r['cityId'] == row['cityId'] &&
            r['calculationMethod'] == row['calculationMethod']);
      }
    }
    tables[table]!.add(row);
    return 1;
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
    if (where == null) return List.from(list);

    return list.where((r) {
      if (where.contains('practiceId = ? AND dateStr >= ? AND dateStr <= ?')) {
        return r['practiceId'] == whereArgs![0] &&
            (r['dateStr'] as String).compareTo(whereArgs[1] as String) >= 0 &&
            (r['dateStr'] as String).compareTo(whereArgs[2] as String) <= 0;
      }
      if (where.contains('date = ? AND cityId = ? AND calculationMethod = ?')) {
        return r['date'] == whereArgs![0] && r['cityId'] == whereArgs[1] && r['calculationMethod'] == whereArgs[2];
      }
      if (where.contains('id = ?')) {
        return r['id'] == whereArgs![0];
      }
      if (where.contains('date = ?')) {
        return r['date'] == whereArgs![0];
      }
      if (where.contains('key IN')) {
        return (whereArgs ?? []).contains(r['key']);
      }
      if (where.contains('isActive = 1')) {
        return r['isActive'] == 1;
      }
      return true;
    }).toList();
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    tables[table] ??= [];
    for (final row in tables[table]!) {
      if (where == null || (where.contains('id = ?') && row['id'] == whereArgs![0])) {
        values.forEach((k, v) => row[k] = v);
      }
    }
    return 1;
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    if (sql.contains('UPDATE worship_debts') && sql.contains('totalCount = totalCount + 1')) {
      final id = arguments!.last;
      for (final r in tables['worship_debts'] ?? []) {
        if (r['id'] == id) {
          r['totalCount'] = (r['totalCount'] as int) + 1;
          r['remainingCount'] = (r['remainingCount'] as int) + 1;
          r['isArchived'] = 0;
        }
      }
    } else if (sql.contains('UPDATE worship_debts') && sql.contains('totalCount - 1')) {
      final id = arguments!.last;
      for (final r in tables['worship_debts'] ?? []) {
        if (r['id'] == id) {
          final t = (r['totalCount'] as int) - 1;
          final rem = (r['remainingCount'] as int) - 1;
          r['totalCount'] = t < 0 ? 0 : t;
          r['remainingCount'] = rem < 0 ? 0 : rem;
        }
      }
    }
    return 1;
  }

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    if (where == null) {
      final count = tables[table]?.length ?? 0;
      tables[table]?.clear();
      return count;
    }
    if (where.contains('id = ?')) {
      tables[table]?.removeWhere((r) => r['id'] == whereArgs![0]);
    }
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeTransaction extends _FakeWorshipDatabase implements Transaction {
  final _FakeWorshipDatabase _parent;
  _FakeTransaction(this._parent);

  @override
  Map<String, List<Map<String, dynamic>>> get tables => _parent.tables;

  @override
  Future<int> insert(String table, Map<String, Object?> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) {
    return _parent.insert(table, values, conflictAlgorithm: conflictAlgorithm);
  }

  @override
  Future<List<Map<String, Object?>>> query(String table, {bool? distinct, List<String>? columns, String? where, List<Object?>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset}) {
    return _parent.query(table, where: where, whereArgs: whereArgs);
  }

  @override
  Future<int> update(String table, Map<String, Object?> values, {String? where, List<Object?>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) {
    return _parent.update(table, values, where: where, whereArgs: whereArgs);
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) {
    return _parent.rawUpdate(sql, arguments);
  }

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) {
    return _parent.delete(table, where: where, whereArgs: whereArgs);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeWorshipDatabase fakeDb;

  setUp(() {
    fakeDb = _FakeWorshipDatabase();
    DatabaseHelper.databaseInstance = fakeDb;
    WorshipEngine.instance.invalidate();
  });

  group('Worship Hardening & Fiqh Invariant Verification Suite', () {
    test('1. PrayerLogQuality.fromCode maps LATE, MISSED, QADA, and QADA_ADDED to qada (C1, H3)', () {
      expect(PrayerLogQuality.fromCode('LATE'), equals(PrayerLogQuality.qada));
      expect(PrayerLogQuality.fromCode('MISSED'), equals(PrayerLogQuality.qada));
      expect(PrayerLogQuality.fromCode('QADA'), equals(PrayerLogQuality.qada));
      expect(PrayerLogQuality.fromCode('QADA_ADDED'), equals(PrayerLogQuality.qada));
      expect(PrayerLogQuality.fromCode('ON_TIME'), equals(PrayerLogQuality.onTime));
      expect(PrayerLogQuality.fromCode('IN_TIME'), equals(PrayerLogQuality.inTime));
    });

    test('2. Retroactive Logging Invariant: Logging DONE on a past date does NOT add Qada debt', () async {
      final pastDateStr = '2026-08-20'; // 5 days ago
      final repo = WorshipCompletionRepository.instance;

      // User missed recording on time, but performed it in time 5 days ago
      final recordId = await repo.logDone(
        practiceId: 'wp_fajr',
        dateStr: pastDateStr,
        practiceType: 'PRAYER',
        quality: PrayerLogQuality.inTime,
      );

      expect(recordId, equals('wc_wp_fajr_2026-08-20'));

      final completions = fakeDb.tables['worship_completions']!;
      expect(completions.length, equals(1));
      expect(completions.first['resultType'], equals('DONE'));
      expect(completions.first['countDone'], equals(1));

      // Absolutely NO debts added to worship_debts table
      final debts = fakeDb.tables['worship_debts']!;
      expect(debts.isEmpty, isTrue);
    });

    test('3. Idempotency & Debts: Repeating logDone with same state does NOT increment debt (C2, M12)', () async {
      final dateStr = '2026-08-21';
      final repo = WorshipCompletionRepository.instance;

      // Log Qada explicitly
      await repo.logDone(
        practiceId: 'wp_dhuhr',
        dateStr: dateStr,
        practiceType: 'PRAYER',
        quality: PrayerLogQuality.qada,
      );

      expect(fakeDb.tables['worship_debts']!.length, equals(1));
      expect(fakeDb.tables['worship_debts']!.first['totalCount'], equals(1));

      // Re-logging or updating existing Qada entry does NOT increment debt count again (Idempotent)
      await repo.logDone(
        practiceId: 'wp_dhuhr',
        dateStr: dateStr,
        practiceType: 'PRAYER',
        quality: PrayerLogQuality.qada,
      );

      expect(fakeDb.tables['worship_debts']!.first['totalCount'], equals(1));
      expect(fakeDb.tables['worship_debts']!.first['remainingCount'], equals(1));
    });

    test('4. Undo Rollback: Undoing a QADA_ADDED entry safely decrements debts and deletes 0-count debt (C3, H11)', () async {
      final dateStr = '2026-08-22';
      final repo = WorshipCompletionRepository.instance;

      // Log Qada
      final recordId = await repo.logDone(
        practiceId: 'wp_maghrib',
        dateStr: dateStr,
        practiceType: 'PRAYER',
        quality: PrayerLogQuality.qada,
      );

      expect(fakeDb.tables['worship_debts']!.first['totalCount'], equals(1));

      // Undo the entry
      final undoSuccess = await repo.undo(recordId);
      expect(undoSuccess, isTrue);

      // Verify completion deleted
      expect(fakeDb.tables['worship_completions']!.isEmpty, isTrue);
      // Verify debt decremented to 0 and deleted
      expect(fakeDb.tables['worship_debts']!.isEmpty, isTrue);
    });

    test('5. WorshipEngine.logDone and logSkip return undoToken formatted worship:recordId (C4)', () async {
      final pastDate = DateTime(2026, 8, 20);
      final resDone = await WorshipEngine.instance.logDone(practiceId: 'wp_tasbih', date: pastDate);

      expect(resDone, isA<WorshipLogOk>());
      final okDone = resDone as WorshipLogOk;
      expect(okDone.undoToken, equals('worship:wc_wp_tasbih_2026-08-20'));

      final resSkip = await WorshipEngine.instance.logSkip(practiceId: 'wp_fajr', date: pastDate, addToQada: true);
      expect(resSkip, isA<WorshipLogOk>());
      final okSkip = resSkip as WorshipLogOk;
      expect(okSkip.undoToken, equals('worship:wc_wp_fajr_2026-08-20'));
    });

    test('6. Fadhilat window direct match (H2)', () {
      final fajr = DateTime(2026, 8, 25, 4, 30);
      final sunrise = DateTime(2026, 8, 25, 6, 0);

      // On-time window for Fajr is first 20 minutes
      final atFajr = DateTime(2026, 8, 25, 4, 40);
      expect(fadhilat.qualityAt(atFajr, fajr, sunrise), equals(PrayerLogQuality.onTime));

      final lateFajr = DateTime(2026, 8, 25, 5, 30);
      expect(fadhilat.qualityAt(lateFajr, fajr, sunrise), equals(PrayerLogQuality.inTime));

      final missedFajr = DateTime(2026, 8, 25, 6, 15);
      expect(fadhilat.qualityAt(missedFajr, fajr, sunrise), equals(PrayerLogQuality.qada));
    });

    test('7. Tabular Hijri conversion is strictly bijective (M5)', () {
      for (var day = 1; day <= 30; day++) {
        final gDate = DateTime(2026, 8, day);
        final hDate = HijriCalendarCalculator.hijriFromGregorian(gDate);
        final convertedG = HijriCalendarCalculator.gregorianFromHijri(hDate.year, hDate.month, hDate.day);
        expect(convertedG.year, equals(gDate.year));
        expect(convertedG.month, equals(gDate.month));
        expect(convertedG.day, equals(gDate.day));
      }
    });

    test('8. PrayerTimeline.nextFromTimes fallback to tomorrow Fajr (M4)', () {
      final now = DateTime(2026, 8, 25, 23, 50); // Late night past Isha
      final times = PrayerTimes(
        date: '2026-08-25',
        cityId: 'TEHRAN',
        fajr: DateTime(2026, 8, 25, 4, 30),
        sunrise: DateTime(2026, 8, 25, 6, 0),
        dhuhr: DateTime(2026, 8, 25, 12, 10),
        asr: DateTime(2026, 8, 25, 16, 0),
        maghrib: DateTime(2026, 8, 25, 19, 30),
        sunset: DateTime(2026, 8, 25, 19, 10),
        isha: DateTime(2026, 8, 25, 20, 30),
        midnightShari: DateTime(2026, 8, 25, 23, 40),
        calculationMethod: 'TEHRAN_GEOPHYSICS',
      );

      final nextSlot = PrayerTimeline.nextFromTimes(times, now);
      expect(nextSlot, isNotNull);
      expect(nextSlot!.key, equals('FAJR'));
      expect(nextSlot.at, equals(DateTime(2026, 8, 26, 4, 30))); // Tomorrow Fajr
    });

    test('9. WorshipSeason recurrence and toMap preservation (H7, H8)', () {
      final season = WorshipSeason(
        id: 'season_beed',
        seasonType: 'AYYAM_AL_BEED',
        title: 'ایام البیض',
        startDate: '13',
        endDate: '15',
        calendar: 'HIJRI',
        isActive: true,
        priorityWeight: 1,
        createdAt: 1000,
        recurrence: 'DAYS_OF_EVERY_HIJRI_MONTH',
        dayList: '[13,14,15]',
        hijriMonth: null,
        recommendedAmal: 'روزه داری',
      );

      final map = season.toMap();
      expect(map['recurrence'], equals('DAYS_OF_EVERY_HIJRI_MONTH'));
      expect(map['dayList'], equals('[13,14,15]'));
      expect(map['recommendedAmal'], equals('روزه داری'));

      const h13 = HijriDate(day: 13, month: 2, year: 1448, monthName: 'صفر', formatted: '۱۳ صفر');
      const h16 = HijriDate(day: 16, month: 2, year: 1448, monthName: 'صفر', formatted: '۱۶ صفر');

      expect(season.isActiveNow(h13), isTrue);
      expect(season.isActiveNow(h16), isFalse);
    });

    test('10. WorshipCalendarLogic Gregorian range formatting across year transition (M3)', () {
      // Dey 1404 (starts in Dec 2025 and ends in Jan 2026)
      final monthData = WorshipCalendarLogic.generateMonthData(1404, 10);
      expect(monthData.gregorianRangeText, isNotEmpty);
      expect(WorshipCalendarLogic.gregorianMonthNamesFa[1], equals('ژانویه'));
      expect(WorshipCalendarLogic.gregorianMonthNamesFa[12], equals('دسامبر'));
    });
  });
}
