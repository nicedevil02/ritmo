import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/goal_steps_agenda_source.dart';

void main() {
  group('Phase M2-F: Friday Weekly Goal Review (M2-14)', () {
    test('M2-14: Weekly goal review card appears only on Fridays when active goals exist', () {
      const source = GoalStepsAgendaSource(
        goalStepsByDate: {},
        activeGoals: [
          {'id': 'goal_1', 'title': 'یادگیری زبان', 'status': 'ACTIVE'},
          {'id': 'goal_2', 'title': 'ورزش منظم', 'status': 'ACTIVE'},
        ],
        isEnabled: true,
      );

      // Friday (2026-08-14 is a Friday)
      final fridayDate = DateTime(2026, 8, 14);
      expect(fridayDate.weekday, equals(DateTime.friday));

      final fridayCtx = AgendaDayContext(
        date: fridayDate,
        dateStr: '2026-08-14',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      final fridayItems = source.itemsForDate(fridayCtx);
      expect(fridayItems, hasLength(1));
      final reviewItem = fridayItems.first;
      expect(reviewItem.id, equals('goal_weekly_review:2026-08-14'));
      expect(reviewItem.kind, equals(AgendaItemKind.reflection));
      expect(reviewItem.title, contains('مرور و ارزیابی هفتگی اهداف'));
      expect(reviewItem.subtitle, contains('۲ هدف فعال'));
      expect(reviewItem.deepLink.targetId, equals('weekly_review'));

      // Saturday (2026-08-15 is Saturday)
      final saturdayDate = DateTime(2026, 8, 15);
      expect(saturdayDate.weekday, equals(DateTime.saturday));

      final saturdayCtx = AgendaDayContext(
        date: saturdayDate,
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      final saturdayItems = source.itemsForDate(saturdayCtx);
      expect(saturdayItems, isEmpty);
    });

    test('M2-14: Weekly goal review card is omitted on Friday if there are no active goals', () {
      const source = GoalStepsAgendaSource(
        goalStepsByDate: {},
        activeGoals: [], // No active goals
        isEnabled: true,
      );

      final fridayCtx = AgendaDayContext(
        date: DateTime(2026, 8, 14), // Friday
        dateStr: '2026-08-14',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      expect(source.itemsForDate(fridayCtx), isEmpty);
    });
  });
}
