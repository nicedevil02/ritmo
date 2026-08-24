import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:ritmo/features/worship/logic/hijri_calendar.dart';
import 'package:ritmo/features/worship/logic/worship_calendar_logic.dart';
import 'package:ritmo/features/worship/logic/worship_occasions_data.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';
import 'package:ritmo/features/worship/presentation/widgets/fullscreen_tasbih_sheet.dart';
import 'package:ritmo/features/worship/presentation/widgets/worship_day_detail_panel.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class _MockWorshipDb implements Database {
  @override
  bool get isOpen => true;

  final Map<String, List<Map<String, dynamic>>> tables = {
    'worship_practices': [],
    'app_settings': [],
    'cycle_logs': [],
    'cycle_periods': [],
    'pending_reminders': [],
    'worship_debts': [],
    'worship_completions': [],
  };

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {}

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    tables[table] ??= [];
    tables[table]!.add(Map<String, dynamic>.from(values));
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
    return tables[table] ?? [];
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async => 1;

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async => 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('Worship Calendar Logic & Conversion Tests', () {
    setUp(() {
      DatabaseHelper.databaseInstance = _MockWorshipDb();
    });
    test('1. Saturday-indexed weekday alignment is correct', () {
      // 2026-08-08 is Saturday
      final sat = DateTime(2026, 8, 8);
      expect(sat.weekday, equals(DateTime.saturday));
      expect(WorshipCalendarLogic.getSaturdayIndexedWeekday(sat), equals(0));

      // 2026-08-09 is Sunday
      final sun = DateTime(2026, 8, 9);
      expect(WorshipCalendarLogic.getSaturdayIndexedWeekday(sun), equals(1));

      // 2026-08-14 is Friday
      final fri = DateTime(2026, 8, 14);
      expect(WorshipCalendarLogic.getSaturdayIndexedWeekday(fri), equals(6));
    });

    test('2. Month length calculation handles Esfand & leap years', () {
      // Month 1 to 6 have 31 days
      expect(WorshipCalendarLogic.getDaysInJalaliMonth(1405, 1), equals(31));
      expect(WorshipCalendarLogic.getDaysInJalaliMonth(1405, 6), equals(31));

      // Month 7 to 11 have 30 days
      expect(WorshipCalendarLogic.getDaysInJalaliMonth(1405, 7), equals(30));
      expect(WorshipCalendarLogic.getDaysInJalaliMonth(1405, 11), equals(30));

      // Month 12 (Esfand) in non-leap year (1402) has 29 days
      expect(WorshipCalendarLogic.getDaysInJalaliMonth(1402, 12), equals(29));

      // Month 12 (Esfand) in leap year (1403) has 30 days
      expect(WorshipCalendarLogic.getDaysInJalaliMonth(1403, 12), equals(30));
    });

    test('3. Grid generation creates valid 35 or 42 cell structure with unified dates', () {
      final monthData = WorshipCalendarLogic.generateMonthData(1405, 5); // Mordad 1405
      expect(monthData.monthName, equals('مرداد'));
      expect(monthData.days.length % 7, equals(0)); // 35 or 42

      final activeDays = monthData.days.where((d) => d.isCurrentMonth).toList();
      expect(activeDays.length, equals(31));

      // Check first active day matches 1 Mordad 1405
      final firstDay = activeDays.first;
      expect(firstDay.jalali.day, equals(1));
      expect(firstDay.jalali.month, equals(5));

      // Derive Hijri & Gregorian from same date
      final expectedHijri = HijriCalendarCalculator.hijriFromGregorian(firstDay.dateTime);
      expect(firstDay.hijri.day, equals(expectedHijri.day));
      expect(firstDay.hijri.month, equals(expectedHijri.month));
    });

    test('4. Worship occasions registry contains ONLY religious events', () {
      // 10 Muharram (Ashura)
      const ashuraH = HijriDate(day: 10, month: 1, year: 1448, monthName: 'محرم', formatted: '۱۰ محرم ۱۴۴۸');
      final ashuraSolar = Jalali(1405, 4, 15);
      final occasions = WorshipOccasionsData.getOccasionsForDay(ashuraSolar, ashuraH);

      expect(occasions.any((o) => o.title.contains('عاشورا')), isTrue);
      expect(occasions.first.isReligiousHoliday, isTrue);

      // Verify secular events are absent
      expect(occasions.any((o) => o.title.contains('سینما')), isFalse);
    });

    test('5. Daily Zikr of the week returns correct Persian dhikr', () {
      expect(WorshipOccasionsData.getDailyZikr(DateTime.saturday), contains('یا رَبَّ الْعالَمین'));
      expect(WorshipOccasionsData.getDailyZikr(DateTime.friday), contains('اللّهُمَّ صَلِّ'));

      // Test parsing the pure title without parentheses count
      final satZikr = WorshipOccasionsData.getDailyZikr(DateTime.saturday);
      final cleanTitle = satZikr.split('(').first.trim();
      expect(cleanTitle, equals('یا رَبَّ الْعالَمین'));
    });

    testWidgets('6. WorshipDayDetailPanel starts daily dhikr in FullscreenTasbihSheet', (tester) async {
      final satDate = DateTime(2026, 8, 8); // Saturday
      final satDay = WorshipCalendarDay(
        dateTime: satDate,
        jalali: Jalali.fromDateTime(satDate),
        hijri: const HijriDate(day: 23, month: 2, year: 1448, monthName: 'صفر', formatted: '۲۳ صفر ۱۴۴۸'),
        isCurrentMonth: true,
        isToday: true,
        isFriday: false,
        occasions: const [],
        dailyZikr: WorshipOccasionsData.getDailyZikr(DateTime.saturday),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                child: WorshipDayDetailPanel(selectedDay: satDay),
              ),
            ),
          ),
        ),
      );

      expect(find.text('شروع ذکر'), findsOneWidget);
      expect(find.text(satDay.dailyZikr), findsOneWidget);

      await tester.tap(find.text('شروع ذکر'));
      await tester.pumpAndSettle();

      // Should open FullscreenTasbihSheet with Saturday dhikr (یا رَبَّ الْعالَمین) and subtitle
      expect(find.byType(FullscreenTasbihSheet), findsOneWidget);
      expect(find.text('یا رَبَّ الْعالَمین'), findsOneWidget);
      expect(find.text('ذکر روز هفته'), findsOneWidget);
      expect(find.text('تسبیحات حضرت زهرا (س)'), findsNothing);
    });

    test('7. HijriCalendarCalculator shifts dates accurately with offsetDays (-2 to +2)', () {
      final baseDate = DateTime(2026, 8, 14); // 24 Mordad 1405
      final h0 = HijriCalendarCalculator.hijriFromGregorian(baseDate, offsetDays: 0);
      final hPlus1 = HijriCalendarCalculator.hijriFromGregorian(baseDate, offsetDays: 1);
      final hMinus1 = HijriCalendarCalculator.hijriFromGregorian(baseDate, offsetDays: -1);
      final hPlus2 = HijriCalendarCalculator.hijriFromGregorian(baseDate, offsetDays: 2);

      expect(hPlus1.day, equals(h0.day + 1 <= HijriCalendarCalculator.daysInMonth(h0.year, h0.month) ? h0.day + 1 : 1));
      expect(hMinus1.day, equals(h0.day - 1 >= 1 ? h0.day - 1 : 30));
      expect(hPlus2.formatted, isNotEmpty);
    });

    test('8. WorshipCalendarLogic.generateMonthData shifts Hijri days and range headers when hijriOffset is applied', () {
      final standardMonth = WorshipCalendarLogic.generateMonthData(1405, 5, hijriOffset: 0);
      final plusOneMonth = WorshipCalendarLogic.generateMonthData(1405, 5, hijriOffset: 1);
      final minusOneMonth = WorshipCalendarLogic.generateMonthData(1405, 5, hijriOffset: -1);

      final firstDayStd = standardMonth.days.firstWhere((d) => d.isCurrentMonth && d.jalali.day == 1);
      final firstDayPlus1 = plusOneMonth.days.firstWhere((d) => d.isCurrentMonth && d.jalali.day == 1);
      final firstDayMinus1 = minusOneMonth.days.firstWhere((d) => d.isCurrentMonth && d.jalali.day == 1);

      expect(firstDayPlus1.hijri.day, isNot(equals(firstDayMinus1.hijri.day)));
      expect(firstDayStd.hijri.day, isNotNull);
      expect(standardMonth.hijriRangeText, isNotEmpty);
      expect(plusOneMonth.hijriRangeText, isNotEmpty);
    });

    test('9. Religious occasions shift on solar calendar with Hijri crescent correction', () {
      // 10 Muharram (Ashura)
      // On standard offset=0, suppose it falls on solar day D.
      // On offset=+1, the same solar day D has hijri.day=11, and day D-1 has hijri.day=10.
      final monthData0 = WorshipCalendarLogic.generateMonthData(1405, 4, hijriOffset: 0); // Tir 1405
      final ashuraDay0 = monthData0.days.where((d) => d.isCurrentMonth && d.occasions.any((o) => o.title.contains('عاشورا'))).toList();

      final monthDataPlus1 = WorshipCalendarLogic.generateMonthData(1405, 4, hijriOffset: 1);
      final ashuraDayPlus1 = monthDataPlus1.days.where((d) => d.isCurrentMonth && d.occasions.any((o) => o.title.contains('عاشورا'))).toList();

      if (ashuraDay0.isNotEmpty && ashuraDayPlus1.isNotEmpty) {
        expect(ashuraDayPlus1.first.jalali.day, equals(ashuraDay0.first.jalali.day - 1));
      }
    });
  });
}
