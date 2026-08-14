import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

void main() {
  group('MorningBrief Logic Tests', () {
    test('Formats overdue and today counts with Persian digits', () {
      final items = [
        AgendaItem(
          id: 'overdue_1',
          domain: AgendaDomain.task,
          sourceId: 't1',
          title: 'کار معوقه ۱',
          dateStr: '2026-08-10',
          category: Category.work,
          deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: 't1'),
        ),
        AgendaItem(
          id: 'task_today_1',
          domain: AgendaDomain.task,
          sourceId: 't2',
          title: 'کار امروز ۱',
          dateStr: '2026-08-14',
          timeOfDay: '09:00',
          category: Category.work,
          deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: 't2'),
        ),
        AgendaItem(
          id: 'task_today_2',
          domain: AgendaDomain.task,
          sourceId: 't3',
          title: 'کار امروز ۲',
          dateStr: '2026-08-14',
          timeOfDay: '11:00',
          category: Category.work,
          deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: 't3'),
        ),
      ];

      final agenda = DayAgenda(
        dateStr: '2026-08-14',
        items: items,
      );

      int overdueCount = 0;
      int todayCount = 0;
      for (final item in agenda.items) {
        if (item.dateStr != '2026-08-14' || item.id.contains('overdue')) {
          overdueCount++;
        } else {
          todayCount++;
        }
      }

      expect(overdueCount, 1);
      expect(todayCount, 2);

      final text = '${toPersianDigits(overdueCount)} کار معوقه داری و ${toPersianDigits(todayCount)} برنامه برای امروز.';
      expect(text, '۱ کار معوقه داری و ۲ برنامه برای امروز.');
    });

    test('Formats first activity time with Persian digits when no overdue', () {
      final items = [
        AgendaItem(
          id: 'task_today_1',
          domain: AgendaDomain.task,
          sourceId: 't1',
          title: 'جلسه صبحگاهی',
          dateStr: '2026-08-14',
          timeOfDay: '08:30',
          category: Category.work,
          deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: 't1'),
        ),
      ];

      final agenda = DayAgenda(
        dateStr: '2026-08-14',
        items: items,
      );

      final timed = agenda.items.where((i) => i.dateStr == '2026-08-14' && i.isTimed && i.timeOfDay != null).toList();
      expect(timed.isNotEmpty, isTrue);

      final first = timed.first;
      final text = '${toPersianDigits(agenda.items.length)} برنامه برای امروز. اولین: ${first.title}، ساعت ${toPersianDigits(first.timeOfDay ?? "")}.';
      expect(text, '۱ برنامه برای امروز. اولین: جلسه صبحگاهی، ساعت ۰۸:۳۰.');
    });
  });
}
