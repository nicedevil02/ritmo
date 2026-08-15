import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sleep_window_resolver.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/appointment_agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/settings/settings_registry.dart';

void main() {
  group('Phase M1-C: Health Appointments & Sleep Band (P7 / M1-8..M1-10)', () {
    test('AppointmentAgendaSource maps doctor visits and vaccinations correctly', () {
      final rows = [
        {
          'id': 'visit_1',
          'type': 'doctor_visit',
          'title': 'ویزیت دکتر احمدی (قلب و عروق)',
          'subtitle': 'کلینیک تخصصی مهر',
          'timeOfDay': '10:30',
          'status': 'UPCOMING',
          'raw': {},
        },
        {
          'id': 'vac_1',
          'type': 'vaccination',
          'title': 'واکسن آنفلوآنزا',
          'subtitle': 'مرکز بهداشت',
          'timeOfDay': null,
          'isDone': false,
          'raw': {},
        },
      ];

      final source = AppointmentAgendaSource(
        appointmentsByDate: {'2026-08-15': rows},
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

      // Doctor visit
      final visitItem = items[0];
      expect(visitItem.id, equals('appointment:doctor_visit_visit_1:2026-08-15'));
      expect(visitItem.domain, equals(AgendaDomain.appointment));
      expect(visitItem.title, equals('ویزیت دکتر احمدی (قلب و عروق)'));
      expect(visitItem.timeOfDay, equals('10:30'));
      expect(visitItem.itemType, equals(AgendaItemType.fixed));
      expect(visitItem.category, equals(Category.medical));
      expect(visitItem.priority, equals(2.0));
      expect(visitItem.completion, equals(AgendaCompletion.pending));

      // Vaccination
      final vacItem = items[1];
      expect(vacItem.id, equals('appointment:vaccination_vac_1:2026-08-15'));
      expect(vacItem.title, equals('واکسن آنفلوآنزا'));
      expect(vacItem.timeOfDay, isNull);
      expect(vacItem.itemType, equals(AgendaItemType.flexible));
      expect(vacItem.category, equals(Category.medical));
    });

    test('M1-8: SleepWindowResolver returns null when bedtime equals wake time (no 24h shadow)', () {
      const resolver = SleepWindowResolver();

      // Equal minutes (e.g. 0:00 vs 0:00 or 23:00 vs 23:00)
      final blockFromMinutes = resolver.resolveFromMinutes(
        plannedBedtimeMin: 420,
        plannedWakeMin: 420,
      );
      expect(blockFromMinutes, isNull);

      final blockFromTimes = resolver.resolveFromTimes(
        bedtime: '07:00',
        wakeTime: '07:00',
      );
      expect(blockFromTimes, isNull);

      // Normal sleep window (crosses midnight: 23:30 -> 07:00)
      final normalBlock = resolver.resolveFromTimes(
        bedtime: '23:30',
        wakeTime: '07:00',
      );
      expect(normalBlock, isNotNull);
      expect(normalBlock!.crossesMidnight, isTrue);
      expect(normalBlock.startMinutes, equals(1410));
      expect(normalBlock.endMinutes, equals(420 + 1440));
    });

    test('M1-10: calendar_show_appointments and calendar_show_sleep_band are registered', () {
      final apptDesc = SettingsRegistry.all.firstWhere(
        (s) => s.key == 'calendar_show_appointments',
        orElse: () => throw Exception('calendar_show_appointments not found'),
      );
      expect(apptDesc.group, equals(SettingsGroup.calendar));
      expect(apptDesc.defaultValue, isTrue);

      final sleepDesc = SettingsRegistry.all.firstWhere(
        (s) => s.key == 'calendar_show_sleep_band',
        orElse: () => throw Exception('calendar_show_sleep_band not found'),
      );
      expect(sleepDesc.group, equals(SettingsGroup.calendar));
      expect(sleepDesc.defaultValue, isTrue);
    });
  });
}
