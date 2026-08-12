import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/today/presentation/home_focus_ranker.dart';

/// سازندهٔ کمکی آیتم تست
AgendaItem _item(
  String id,
  String? time, {
  AgendaCompletion completion = AgendaCompletion.none,
  AgendaDomain domain = AgendaDomain.routine,
}) {
  return AgendaItem(
    id: '${domain.name}:$id',
    domain: domain,
    sourceId: id,
    title: 'آیتم $id',
    dateStr: '2026-08-12',
    timeOfDay: time,
    category: Category.personal,
    completion: completion,
    deepLink: AgendaDeepLink(domain: domain, targetId: id),
  );
}

/// ظهرِ روز مرجع — نقطهٔ ثابت همهٔ تستها
final _noon = DateTime(2026, 8, 12, 12, 0);

void main() {
  group('HomeFocusRanker', () {
    test('T1: ورودی کاملاً خالی ⇒ emptyState', () {
      final d = HomeFocusRanker.decide(HomeFocusInput(now: _noon));
      expect(d.level, HomeFocusLevel.emptyState);
    });

    test('T2: فقط نیاز به چکاین ⇒ morningCheckIn', () {
      final d = HomeFocusRanker.decide(
          HomeFocusInput(now: _noon, needCheckin: true));
      expect(d.level, HomeFocusLevel.morningCheckIn);
    });

    test('T3: تایمر فعال بر چکاین غلبه میکند', () {
      final d = HomeFocusRanker.decide(HomeFocusInput(
          now: _noon, hasActiveTimer: true, needCheckin: true));
      expect(d.level, HomeFocusLevel.activeTimer);
    });

    test('T4: دوز باقیمانده بر آیتم Agenda غلبه میکند', () {
      final d = HomeFocusRanker.decide(HomeFocusInput(
        now: _noon,
        medicineModuleEnabled: true,
        pendingMedDoses: 2,
        agendaItems: [_item('a', '14:00')],
      ));
      expect(d.level, HomeFocusLevel.medicalDue);
    });

    test('T5: تایمر فعال بر دوز دارو غلبه میکند (قانون سند v2)', () {
      final d = HomeFocusRanker.decide(HomeFocusInput(
        now: _noon,
        hasActiveTimer: true,
        medicineModuleEnabled: true,
        pendingMedDoses: 3,
      ));
      expect(d.level, HomeFocusLevel.activeTimer);
    });

    test('T6: بحران دارویی — تنها سطحی که تایمر را کنار میزند', () {
      final d = HomeFocusRanker.decide(HomeFocusInput(
        now: _noon,
        hasActiveTimer: true,
        medicineModuleEnabled: true,
        medicalCriticalCount: 1,
      ));
      expect(d.level, HomeFocusLevel.medicalCritical);
    });

    test('T7: انتخاب نزدیکترین آیتم آینده (نه گذشته)', () {
      final d = HomeFocusRanker.decide(HomeFocusInput(
        now: _noon,
        agendaItems: [_item('past', '09:00'), _item('future', '14:00')],
      ));
      expect(d.level, HomeFocusLevel.agendaItem);
      expect(d.agendaItem!.sourceId, 'future');
      expect(d.isOverdue, isFalse);
    });

    test('T8: وقتی همه گذشتهاند ⇒ قدیمیترین عقبافتاده', () {
      final d = HomeFocusRanker.decide(HomeFocusInput(
        now: _noon,
        agendaItems: [_item('b', '10:30'), _item('a', '08:00')],
      ));
      expect(d.level, HomeFocusLevel.agendaItem);
      expect(d.agendaItem!.sourceId, 'a');
      expect(d.isOverdue, isTrue);
    });

    test('T9: بدهی عبادی از نامزدها حذف میشود', () {
      final d = HomeFocusRanker.decide(HomeFocusInput(
        now: _noon,
        agendaItems: [_item('debt', '14:00', domain: AgendaDomain.worshipDebt)],
      ));
      expect(d.level, HomeFocusLevel.emptyState);
    });

    test('T10: ماژول دارو غیرفعال ⇒ دوزها نادیده گرفته میشوند', () {
      final d = HomeFocusRanker.decide(HomeFocusInput(
        now: _noon,
        medicineModuleEnabled: false,
        pendingMedDoses: 5,
        agendaItems: [_item('a', '14:00')],
      ));
      expect(d.level, HomeFocusLevel.agendaItem);
    });

    test('T11: بدون Agenda ولی با کار روتینی ⇒ agendaFallback', () {
      final d = HomeFocusRanker.decide(HomeFocusInput(
          now: _noon, fallbackTasksPending: true));
      expect(d.level, HomeFocusLevel.agendaFallback);
    });

    test('T12: آیتمهای انجامشده و بدونزمان نادیده گرفته میشوند', () {
      final d = HomeFocusRanker.decide(HomeFocusInput(
        now: _noon,
        agendaItems: [
          _item('done', '14:00', completion: AgendaCompletion.done),
          _item('untimed', null),
        ],
      ));
      expect(d.level, HomeFocusLevel.emptyState);
    });
  });
}
