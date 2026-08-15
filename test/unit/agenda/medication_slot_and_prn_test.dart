import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/medicine_agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';

void main() {
  group('Phase M2-A: Slot-aware Medication Deep Link and PRN Logging (P12 / M2-1..M2-2)', () {
    final scheduledRoutine = {
      'id': 'med_scheduled_1',
      'title': 'قرص فشار خون',
      'itemType': 'ROUTINE',
      'category': 'medical',
      'isArchived': 0,
    };

    final scheduledSchedule = {
      'routineId': 'med_scheduled_1',
      'scheduleType': 'FIXED_TIME',
      'timeOfDay': '08:00',
      'recurrenceRule': '{"type":"daily","reminderTimes":["08:00","20:00"]}',
    };

    final prnRoutine = {
      'id': 'med_prn_1',
      'title': 'اسپری سالبوتامول',
      'itemType': 'ROUTINE',
      'routineType': 'asNeeded',
      'category': 'medical',
      'isArchived': 0,
    };

    final prnSchedule = {
      'routineId': 'med_prn_1',
      'scheduleType': 'AS_NEEDED',
    };

    test('M2-1: Scheduled medication slot carries slot in deepLink and timeOfDay', () {
      final source = MedicineAgendaSource(
        medicationRoutines: [
          {'routine': scheduledRoutine, 'schedule': scheduledSchedule},
        ],
        logsByRoutineAndDate: {},
        medicineEnabled: true,
      );

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 15),
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      final items = source.itemsForDate(ctx);
      expect(items, hasLength(2));

      // First slot: 08:00
      final item08 = items[0];
      expect(item08.timeOfDay, equals('08:00'));
      expect(item08.deepLink.slot, equals('08:00'));
      expect(item08.deepLink.targetId, equals('med_scheduled_1'));
      expect(item08.itemType, equals(AgendaItemType.fixed));
      expect(item08.category, equals(Category.medical));

      // Second slot: 20:00
      final item20 = items[1];
      expect(item20.timeOfDay, equals('20:00'));
      expect(item20.deepLink.slot, equals('20:00'));
    });

    test('M2-2: PRN medication produces optional action item on today allowing logging from calendar', () {
      final source = MedicineAgendaSource(
        medicationRoutines: [
          {'routine': prnRoutine, 'schedule': prnSchedule},
        ],
        logsByRoutineAndDate: {},
        medicineEnabled: true,
      );

      // 1. On today: has PRN action item
      final todayCtx = AgendaDayContext(
        date: DateTime.now(),
        dateStr: DateTime.now().toIso8601String().substring(0, 10),
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      final todayItems = source.itemsForDate(todayCtx);
      expect(todayItems, hasLength(1));
      expect(todayItems.first.sourceId, equals('med_prn_1'));
      expect(todayItems.first.title, equals('اسپری سالبوتامول'));
      expect(todayItems.first.meta['isPrnAction'], isTrue);
      expect(todayItems.first.itemType, equals(AgendaItemType.flexible));
      expect(todayItems.first.completion, equals(AgendaCompletion.pending));

      // 2. On future/past day without logs: no spurious placeholder
      final futureCtx = AgendaDayContext(
        date: DateTime.now().add(const Duration(days: 3)),
        dateStr: '2026-08-18',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      final futureItems = source.itemsForDate(futureCtx);
      expect(futureItems, isEmpty);
    });
  });
}
