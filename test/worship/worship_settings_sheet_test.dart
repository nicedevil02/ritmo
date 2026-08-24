// test/worship/worship_settings_sheet_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/worship/presentation/widgets/worship_settings_sheet.dart';
import 'package:sqflite/sqflite.dart';

class _MockSettingsDatabase implements Database {
  @override
  bool get isOpen => true;

  final Map<String, List<Map<String, dynamic>>> tables = {
    'app_settings': [
      {'key': 'prayer_city_id', 'value': 'TEHRAN_TEHRAN'},
      {'key': 'prayer_calculation_method', 'value': 'TEHRAN_GEOPHYSICS'},
      {'key': 'show_asr_isha_prayers', 'value': 'false'},
      {'key': 'hijri_offset', 'value': '0'},
      {'key': 'worship_adhan_enabled', 'value': 'true'},
      {'key': 'worship_adhan_fajr', 'value': 'true'},
      {'key': 'worship_adhan_dhuhr', 'value': 'true'},
      {'key': 'worship_adhan_maghrib', 'value': 'true'},
      {'key': 'worship_pre_reminder_minutes', 'value': '10'},
      {'key': 'worship_night_prayer_reminder', 'value': 'false'},
      {'key': 'worship_auto_debt_sweep', 'value': 'true'},
      {'key': 'calendar_show_worship_obligatory', 'value': 'true'},
      {'key': 'calendar_show_worship_mustahab', 'value': 'true'},
      {'key': 'calendar_show_worship_qada', 'value': 'true'},
    ],
    'iran_cities': [
      {'id': 'TEHRAN_TEHRAN', 'city': 'تهران', 'province': 'تهران'},
    ],
    'prayer_times_cache': [],
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
    final existingIndex = tables[table]!.indexWhere((row) => row['key'] == values['key']);
    if (existingIndex >= 0) {
      tables[table]![existingIndex] = Map<String, dynamic>.from(values);
    } else {
      tables[table]!.add(Map<String, dynamic>.from(values));
    }
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
    if (where == null) return list;
    if (table == 'iran_cities' && where.contains('id = ?')) {
      final idVal = whereArgs![0] as String;
      return list.where((r) => r['id'] == idVal).toList();
    }
    return list;
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
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    tables[table]?.clear();
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('WorshipSettingsSheet Redesign Tests', () {
    late _MockSettingsDatabase mockDb;

    setUp(() {
      mockDb = _MockSettingsDatabase();
      DatabaseHelper.databaseInstance = mockDb;
    });

    testWidgets('1. Renders all 5 sections and excludes menstruation exemption', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: Scaffold(
            body: WorshipSettingsSheet(onChanged: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('تنظیمات عبادت و معنویت'), findsOneWidget);

      // Verify Section Headers
      expect(find.text('موقعیت مکانی و روش محاسبه'), findsOneWidget);
      expect(find.text('تقویم قمری و تصحیح هلال ماه'), findsOneWidget);
      expect(find.text('اذان و یادآورهای صوتی'), findsOneWidget);
      expect(find.text('قضا و ثبت معوقات'), findsOneWidget);
      expect(find.text('نمایش در تقویم ریتمو'), findsOneWidget);

      // Verify Menstruation rule is EXCLUDED per user directive
      expect(find.textContaining('معافیت شرعی'), findsNothing);
      expect(find.textContaining('بانوان'), findsNothing);
      expect(find.textContaining('قاعدگی'), findsNothing);

      // Verify Current City Tile
      expect(find.text('شهر / موقعیت مکانی'), findsOneWidget);
      expect(find.text('تهران'), findsOneWidget);
      expect(find.text('تغییر شهر'), findsOneWidget);

      // Verify Adhan Switch and Pre-reminder
      expect(find.text('پخش اذان صوتی'), findsOneWidget);
      expect(find.text('اذان صبح'), findsOneWidget);
      expect(find.text('اذان ظهر'), findsOneWidget);
      expect(find.text('اذان مغرب'), findsOneWidget);

      // Verify Qada & Calendar Switches
      expect(find.text('ثبت خودکار نمازهای نخوانده در قضا'), findsOneWidget);
      expect(find.text('نمایش نمازهای واجب در تقویم'), findsOneWidget);
      expect(find.text('نمایش مستحبات و مناسبت‌ها در تقویم'), findsOneWidget);
      expect(find.text('نمایش بدهی‌های قضا در تقویم'), findsOneWidget);
    });

    testWidgets('2. Toggling switches updates settings state', (tester) async {
      bool changedCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: Scaffold(
            body: WorshipSettingsSheet(
              onChanged: () {
                changedCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find first visible switch (asr_isha) and toggle it
      final firstSwitch = find.byType(Switch).first;
      await tester.tap(firstSwitch);
      await tester.pumpAndSettle();

      expect(changedCalled, isTrue);
    });
  });
}
