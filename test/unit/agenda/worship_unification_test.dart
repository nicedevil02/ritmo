import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/worship_agenda_source.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:sqflite/sqflite.dart';

class _FakeDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final fakeDb = _FakeDatabase();

  group('Phase M2-E: Worship Day Exceptions, Floating Mustahabs, & Overrides (P8 / M2-10..M2-13)', () {
    test('M2-10: Day exception suppresses obligatory prayers on that date', () {
      final source = WorshipAgendaSource(
        prayerPractices: [
          {'id': 'fajr_practice', 'subType': 'FAJR', 'title': 'نماز صبح'},
        ],
        mustahabPractices: [],
        worshipDebts: [],
        settingsMap: const {'module_religion_enabled': 'true'},
        religionEnabled: true,
        cachedHijriDates: const {},
        statusesByDate: const {},
        contextsByDate: const {},
        hasLunarMonthly: false,
        db: fakeDb,
        exceptionsByDate: {
          '2026-08-15': {
            'dateStr': '2026-08-15',
            'reason': 'MENSTRUATION',
            'suppressObligatory': 1,
            'suppressMustahab': 0,
          },
        },
      );

      // On 2026-08-15: prayer is suppressed
      final suppressedCtx = AgendaDayContext(
        date: DateTime(2026, 8, 15),
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {'fajr': '04:30', 'sunrise': '06:00'},
        options: const AgendaQueryOptions(),
      );
      expect(source.itemsForDate(suppressedCtx), isEmpty);

      // On 2026-08-16 (no exception): prayer is present
      final normalCtx = AgendaDayContext(
        date: DateTime(2026, 8, 16),
        dateStr: '2026-08-16',
        isToday: false,
        prayerTimes: const {'fajr': '04:31', 'sunrise': '06:01'},
        options: const AgendaQueryOptions(),
      );
      expect(source.itemsForDate(normalCtx), hasLength(1));
      expect(source.itemsForDate(normalCtx).first.title, equals('نماز صبح'));
    });

    test('M2-11: Floating Mustahab has AgendaItemType.floating and kind practice with progress subtitle', () {
      final source = WorshipAgendaSource(
        prayerPractices: [],
        mustahabPractices: [
          {
            'id': 'dhikr_salawat',
            'title': 'صلوات روزانه',
            'practiceType': 'DHIKR',
            'dailyTarget': 100,
            'dailyDone': 30,
            'reminderFrequency': 'DAILY',
            'reminderAnchor': 'NONE',
            'reminderTimes': null,
            'reminderTime': null,
          },
        ],
        worshipDebts: [],
        settingsMap: const {'module_religion_enabled': 'true'},
        religionEnabled: true,
        cachedHijriDates: const {},
        statusesByDate: const {},
        contextsByDate: const {},
        hasLunarMonthly: false,
        db: fakeDb,
      );

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 15),
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      final items = source.itemsForDate(ctx);
      expect(items, hasLength(1));
      final item = items.first;
      expect(item.title, equals('صلوات روزانه'));
      expect(item.itemType, equals(AgendaItemType.floating));
      expect(item.kind, equals(AgendaItemKind.practice));
      expect(item.subtitle, contains('۳۰ از ۱۰۰'));
    });

    test('M2-12: Occurrence override with status SKIPPED skips worship practice on target date', () {
      final source = WorshipAgendaSource(
        prayerPractices: [],
        mustahabPractices: [
          {
            'id': 'ziyarat_ashura',
            'title': 'زیارت عاشورا',
            'practiceType': 'MUSTAHAB',
            'dailyTarget': 1,
            'reminderFrequency': 'DAILY',
            'reminderAnchor': 'NONE',
            'reminderTime': '08:00',
          },
        ],
        worshipDebts: [],
        settingsMap: const {'module_religion_enabled': 'true'},
        religionEnabled: true,
        cachedHijriDates: const {},
        statusesByDate: const {},
        contextsByDate: const {},
        hasLunarMonthly: false,
        db: fakeDb,
        overridesByKey: {
          'ziyarat_ashura_2026-08-15': {
            'sourceType': 'WORSHIP',
            'sourceId': 'ziyarat_ashura',
            'dateStr': '2026-08-15',
            'status': 'SKIPPED',
          },
        },
      );

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 15),
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      expect(source.itemsForDate(ctx), isEmpty);
    });

    test('M2-13: Worship calendar settings registered in SettingsRegistry', () {
      final obligatory = SettingsRegistry.all.firstWhere(
        (s) => s.key == 'calendar_show_worship_obligatory',
      );
      expect(obligatory.group, equals(SettingsGroup.calendar));
      expect(obligatory.defaultValue, isTrue);

      final mustahab = SettingsRegistry.all.firstWhere(
        (s) => s.key == 'calendar_show_worship_mustahab',
      );
      expect(mustahab.group, equals(SettingsGroup.calendar));
      expect(mustahab.defaultValue, isTrue);

      final qada = SettingsRegistry.all.firstWhere(
        (s) => s.key == 'calendar_show_worship_qada',
      );
      expect(qada.group, equals(SettingsGroup.calendar));
      expect(qada.defaultValue, isFalse);
    });
  });
}
