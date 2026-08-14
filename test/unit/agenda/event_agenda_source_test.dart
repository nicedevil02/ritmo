import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/event_agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/settings/settings_registry.dart';

void main() {
  group('Phase 4 — Read-only EventAgendaSource (P2 / W4-1..W4-4)', () {
    test('converts temporary_events rows into properly mapped AgendaItem objects', () {
      final rows = [
        {
          'id': 'temp_1001',
          'title': 'جلسه تیم محصول',
          'date': '2026-08-14',
          'startTime': '10:00',
          'endTime': '11:30',
          'durationMinutes': 90,
          'isLocked': 1,
          'createdAt': 1786645887305,
        },
        {
          'id': 'temp_1002',
          'title': 'تماس کاری انعطاف‌پذیر',
          'date': '2026-08-14',
          'startTime': '14:00',
          'endTime': '14:30',
          'durationMinutes': 30,
          'isLocked': 0,
          'createdAt': 1786645887306,
        },
        {
          'id': 'temp_1003',
          'title': 'رویداد روز دیگر',
          'date': '2026-08-15',
          'startTime': '09:00',
          'endTime': '10:00',
          'durationMinutes': 60,
          'isLocked': 0,
          'createdAt': 1786645887307,
        },
      ];

      final source = EventAgendaSource(events: rows);
      expect(source.domains, equals({AgendaDomain.event}));
      expect(source.isEnabled, isTrue);

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 14),
        dateStr: '2026-08-14',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      final items = source.itemsForDate(ctx);
      expect(items, hasLength(2));

      // First item (Locked -> fixed, isEssential = false, completion = none)
      final item1 = items[0];
      expect(item1.id, equals('event:temp_1001:2026-08-14'));
      expect(item1.domain, equals(AgendaDomain.event));
      expect(item1.sourceId, equals('temp_1001'));
      expect(item1.title, equals('جلسه تیم محصول'));
      expect(item1.dateStr, equals('2026-08-14'));
      expect(item1.timeOfDay, equals('10:00'));
      expect(item1.durationMinutes, equals(90));
      expect(item1.windowStart, equals(DateTime(2026, 8, 14, 10, 0)));
      expect(item1.windowEnd, equals(DateTime(2026, 8, 14, 11, 30)));
      expect(item1.category, equals(Category.custom));
      expect(item1.itemType, equals(AgendaItemType.fixed));
      expect(item1.isEssential, isFalse);
      expect(item1.completion, equals(AgendaCompletion.none));
      expect(item1.deepLink.domain, equals(AgendaDomain.event));

      // Second item (Unlocked -> flexible)
      final item2 = items[1];
      expect(item2.id, equals('event:temp_1002:2026-08-14'));
      expect(item2.itemType, equals(AgendaItemType.flexible));
      expect(item2.isEssential, isFalse);
    });

    test('disabled factory produces empty list', () {
      final source = EventAgendaSource.disabled();
      expect(source.isEnabled, isFalse);

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 14),
        dateStr: '2026-08-14',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      final items = source.itemsForDate(ctx);
      expect(items, isEmpty);
    });

    test('calendar_show_events is registered in SettingsRegistry', () {
      final desc = SettingsRegistry.all.firstWhere(
        (s) => s.key == 'calendar_show_events',
        orElse: () => throw Exception('calendar_show_events not found in SettingsRegistry'),
      );

      expect(desc.group, equals(SettingsGroup.calendar));
      expect(desc.type, equals(SettingType.boolean));
      expect(desc.defaultValue, isTrue);
    });
  });
}
