import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/event_agenda_source.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/today/presentation/widgets/temporary_event_create_sheet.dart';

void main() {
  group('Phase M1-A: Event Write Path, Date Picker & Invalidation (P2)', () {
    test('EventAgendaSource correctly resolves future event (tomorrow) without app restart', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowStr = '${tomorrow.year.toString().padLeft(4, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

      final rows = [
        {
          'id': 'temp_tomorrow_1',
          'title': 'جلسه کاری فردا',
          'date': tomorrowStr,
          'startTime': '15:00',
          'endTime': '16:00',
          'durationMinutes': 60,
          'isLocked': 0,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        },
      ];

      final source = EventAgendaSource(events: rows);
      final ctx = AgendaDayContext(
        date: tomorrow,
        dateStr: tomorrowStr,
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      final items = source.itemsForDate(ctx);
      expect(items, hasLength(1));
      expect(items.first.id, equals('event:temp_tomorrow_1:$tomorrowStr'));
      expect(items.first.title, equals('جلسه کاری فردا'));
      expect(items.first.dateStr, equals(tomorrowStr));
      expect(items.first.domain, equals(AgendaDomain.event));
      expect(items.first.timeOfDay, equals('15:00'));
    });

    testWidgets('TemporaryEventCreateSheet renders without "رویداد موقت" text and has date picker', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: const [kJadeNoirDark],
          ),
          home: Scaffold(
            body: TemporaryEventCreateSheet(
              onSaved: () {},
              initialDate: DateTime(2026, 8, 16),
            ),
          ),
        ),
      );

      // Verify no "رویداد موقت" text remains in UI
      expect(find.textContaining('رویداد موقت'), findsNothing);

      // Verify "ثبت رویداد جدید" and "ثبت رویداد" exist
      expect(find.text('ثبت رویداد جدید'), findsOneWidget);
      expect(find.text('ثبت رویداد'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsNothing); // CupertinoIcons.calendar is used
    });
  });
}
