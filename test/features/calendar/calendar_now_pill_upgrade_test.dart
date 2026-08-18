import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/calendar/presentation/models/now_pill_view_model.dart';

void main() {
  group('CAL-51: NowPillViewModel Upgrades & Boundary Conditions', () {
    final item1 = AgendaItem(
      id: 'i1',
      sourceId: 's1',
      title: 'جلسه صبحگاهی',
      domain: AgendaDomain.routine,
      category: Category.work,
      dateStr: '2026-08-18',
      timeOfDay: '09:00',
      durationMinutes: 60,
      deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 's1'),
    );

    final item2 = AgendaItem(
      id: 'i2',
      sourceId: 's2',
      title: 'ورزش عصرگاهی',
      domain: AgendaDomain.sport,
      category: Category.fitness,
      dateStr: '2026-08-18',
      timeOfDay: '17:00',
      durationMinutes: 45,
      deepLink: const AgendaDeepLink(domain: AgendaDomain.sport, targetId: 's2'),
    );

    test('1. Before first item: displays NEXT with relative countdown', () {
      final now = DateTime(2026, 8, 18, 8, 30);
      final snapshot = DayAgendaSnapshot(
        dayAgenda: DayAgenda(dateStr: '2026-08-18', items: [item1, item2]),
        completedCount: 0,
        remainingCount: 2,
        freeGaps: const [],
        conflicts: const [],
        overloadScore: 0,
        nextActivity: item1,
        suggestions: const [],
      );

      final vm = NowPillViewModel.fromSnapshot(snapshot, now: now, isToday: true);
      expect(vm.isVisible, isTrue);
      expect(vm.isCurrent, isFalse);
      expect(vm.statusLabel, equals('NEXT'));
      expect(vm.targetItem?.title, equals('جلسه صبحگاهی'));
      expect(vm.isOverdue, isFalse);
    });

    test('2. During current item: displays NOW with remaining minutes and next item title', () {
      final now = DateTime(2026, 8, 18, 9, 20); // 40 minutes remaining
      final snapshot = DayAgendaSnapshot(
        dayAgenda: DayAgenda(dateStr: '2026-08-18', items: [item1, item2]),
        completedCount: 0,
        remainingCount: 2,
        freeGaps: const [],
        conflicts: const [],
        overloadScore: 0,
        currentActivity: item1,
        nextActivity: item2,
        suggestions: const [],
      );

      final vm = NowPillViewModel.fromSnapshot(snapshot, now: now, isToday: true);
      expect(vm.isVisible, isTrue);
      expect(vm.isCurrent, isTrue);
      expect(vm.statusLabel, equals('NOW'));
      expect(vm.targetItem?.title, equals('جلسه صبحگاهی'));
      expect(vm.remainingMinutesCurrent, equals(40));
      expect(vm.timeLabel, contains(toPersianDigits('40')));
      expect(vm.nextItemTitle, equals('ورزش عصرگاهی'));
    });

    test('3. Between two items: displays NEXT for subsequent item', () {
      final now = DateTime(2026, 8, 18, 14, 0); // between 10:00 and 17:00
      final snapshot = DayAgendaSnapshot(
        dayAgenda: DayAgenda(dateStr: '2026-08-18', items: [item1, item2]),
        completedCount: 1,
        remainingCount: 1,
        freeGaps: const [],
        conflicts: const [],
        overloadScore: 0,
        previousActivity: item1,
        nextActivity: item2,
        suggestions: const [],
      );

      final vm = NowPillViewModel.fromSnapshot(snapshot, now: now, isToday: true);
      expect(vm.isVisible, isTrue);
      expect(vm.isCurrent, isFalse);
      expect(vm.statusLabel, equals('NEXT'));
      expect(vm.targetItem?.title, equals('ورزش عصرگاهی'));
    });

    test('4. After last item: displays DONE status when all items finished', () {
      final now = DateTime(2026, 8, 18, 20, 0);
      final snapshot = DayAgendaSnapshot(
        dayAgenda: DayAgenda(dateStr: '2026-08-18', items: [item1, item2]),
        completedCount: 2,
        remainingCount: 0,
        freeGaps: const [],
        conflicts: const [],
        overloadScore: 0,
        previousActivity: item2,
        suggestions: const [],
      );

      final vm = NowPillViewModel.fromSnapshot(snapshot, now: now, isToday: true);
      expect(vm.isVisible, isTrue);
      expect(vm.statusLabel, equals('DONE'));
      expect(vm.timeLabel, contains('تمام شد'));
    });

    test('5. Empty day: hidden', () {
      final now = DateTime(2026, 8, 18, 12, 0);
      const snapshot = DayAgendaSnapshot(
        dayAgenda: DayAgenda(dateStr: '2026-08-18', items: []),
        completedCount: 0,
        remainingCount: 0,
        freeGaps: [],
        conflicts: [],
        overloadScore: 0,
        suggestions: [],
      );

      final vm = NowPillViewModel.fromSnapshot(snapshot, now: now, isToday: true);
      expect(vm.isVisible, isFalse);
    });
  });
}
