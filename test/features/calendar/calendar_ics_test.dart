import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/ics_agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';

void main() {
  group('CAL-52: ICS Import, Export & Round-Trip', () {
    const sampleIcs = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Google Inc//Google Calendar 70.9054//EN
CALSCALE:GREGORIAN
BEGIN:VEVENT
DTSTART:20260818T100000Z
DTEND:20260818T113000Z
DTSTAMP:20260818T080000Z
UID:sample_event_123@google.com
SUMMARY:جلسه طراحی محصول
DESCRIPTION:بررسی نقشه راه نسخه جدید تقویم
LOCATION:اتاق کنفرانس ۳
STATUS:CONFIRMED
END:VEVENT
BEGIN:VEVENT
DTSTART:20260819T140000
DTEND:20260819T150000
UID:sample_event_456@google.com
SUMMARY:کارگاه آموزشی فلاتر
RRULE:FREQ=WEEKLY;BYDAY=WE
END:VEVENT
END:VCALENDAR
''';

    test('1. Parses ICS sample into IcsEvent objects with correct dates and times', () {
      final events = IcsParser.parse(sampleIcs);
      expect(events.length, equals(2));

      final first = events[0];
      expect(first.uid, equals('sample_event_123@google.com'));
      expect(first.summary, equals('جلسه طراحی محصول'));
      expect(first.dateStr, equals('2026-08-18'));
      expect(first.startTime, equals('10:00'));
      expect(first.endTime, equals('11:30'));
      expect(first.durationMinutes, equals(90));
      expect(first.description, equals('بررسی نقشه راه نسخه جدید تقویم'));
      expect(first.location, equals('اتاق کنفرانس ۳'));
      expect(first.hasRRule, isFalse);

      final second = events[1];
      expect(second.uid, equals('sample_event_456@google.com'));
      expect(second.summary, equals('کارگاه آموزشی فلاتر'));
      expect(second.dateStr, equals('2026-08-19'));
      expect(second.startTime, equals('14:00'));
      expect(second.durationMinutes, equals(60));
      expect(second.hasRRule, isTrue);
    });

    test('2. Converts parsed ICS into normalized AgendaItem instances', () {
      final agendaItems = IcsParser.parseToAgendaItems(sampleIcs);
      expect(agendaItems.length, equals(2));

      final item = agendaItems.first;
      expect(item.domain, equals(AgendaDomain.event));
      expect(item.kind, equals(AgendaItemKind.event));
      expect(item.category, equals(Category.personal));
      expect(item.title, equals('جلسه طراحی محصول'));
      expect(item.dateStr, equals('2026-08-18'));
      expect(item.timeOfDay, equals('10:00'));
      expect(item.durationMinutes, equals(90));
    });

    test('3. Exports AgendaItems to valid RFC 5545 ICS and verifies round-trip parsing', () {
      final originalItems = [
        AgendaItem(
          id: 'item_exp_1',
          sourceId: 'src_1',
          title: 'جلسه برنامه‌ریزی هفتگی',
          domain: AgendaDomain.event,
          kind: AgendaItemKind.event,
          category: Category.work,
          dateStr: '2026-08-20',
          timeOfDay: '15:30',
          durationMinutes: 45,
          deepLink: const AgendaDeepLink(domain: AgendaDomain.event, targetId: 'src_1'),
        ),
      ];

      final exportedIcs = IcsExporter.exportToIcs(originalItems);
      expect(exportedIcs, contains('BEGIN:VCALENDAR'));
      expect(exportedIcs, contains('BEGIN:VEVENT'));
      expect(exportedIcs, contains('SUMMARY:جلسه برنامه‌ریزی هفتگی'));
      expect(exportedIcs, contains('DTSTART:20260820T153000'));
      expect(exportedIcs, contains('DTEND:20260820T161500'));
      expect(exportedIcs, contains('END:VCALENDAR'));

      // Round-trip parse
      final reParsedEvents = IcsParser.parse(exportedIcs);
      expect(reParsedEvents.length, equals(1));
      expect(reParsedEvents.first.summary, equals('جلسه برنامه‌ریزی هفتگی'));
      expect(reParsedEvents.first.dateStr, equals('2026-08-20'));
      expect(reParsedEvents.first.startTime, equals('15:30'));
      expect(reParsedEvents.first.durationMinutes, equals(45));
    });
  });
}
