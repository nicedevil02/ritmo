import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/routine_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/task_agenda_source.dart';
import 'package:ritmo/core/modules/module_gate.dart';

void main() {
  const samplePrayerTimes = {
    'fajr': '05:00',
    'sunrise': '06:30',
    'dhuhr': '12:00',
    'maghrib': '19:00',
    'midnightShari': '23:30',
  };

  group('Sports Module Disabling & Agenda Leak Prevention', () {
    test('ModuleGate.isCategoryEnabledFrom correctly respects sports settings', () {
      final settingsDisabled = {
        'module_sports_enabled': 'false',
        'module_supplementary_sports_enabled': 'false',
      };
      final settingsEnabled = {
        'module_sports_enabled': 'true',
        'module_supplementary_sports_enabled': 'true',
      };

      expect(
        ModuleGate.instance.isCategoryEnabledFrom(settingsDisabled, 'fitness'),
        isFalse,
      );
      expect(
        ModuleGate.instance.isCategoryEnabledFrom(settingsDisabled, 'sports'),
        isFalse,
      );
      expect(
        ModuleGate.instance.isCategoryEnabledFrom(settingsEnabled, 'fitness'),
        isTrue,
      );
    });

    test('RoutineAgendaSource skips fitness & sports routines when activeModules[sports] is false', () {
      final routines = [
        {
          'id': 'routine_fitness_1',
          'title': 'تمرین قدرتی خانگی',
          'category': 'fitness',
          'itemType': 'ROUTINE',
          'targetDurationMinutes': 45,
        },
        {
          'id': 'routine_personal_1',
          'title': 'نوشیدن آب',
          'category': 'personal',
          'itemType': 'ROUTINE',
          'targetDurationMinutes': 5,
        },
      ];

      final schedules = routines.map((r) => {
        'routineId': r['id'],
        'scheduleType': 'FIXED_TIME',
        'timeOfDay': '08:00',
      }).toList();

      final sourceWithSportsDisabled = RoutineAgendaSource(
        routines: routines,
        schedules: schedules,
        occurrences: const [],
        avgDurations: const {},
        categoryAvgDurations: const {},
        completionsByDate: const {},
        activeModules: const {'sports': false},
      );

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 27),
        dateStr: '2026-08-27',
        isToday: true,
        prayerTimes: samplePrayerTimes,
        options: const AgendaQueryOptions(),
      );

      final items = sourceWithSportsDisabled.itemsForDate(ctx);
      expect(items.any((i) => i.title == 'تمرین قدرتی خانگی'), isFalse);
      expect(items.any((i) => i.title == 'نوشیدن آب'), isTrue);
    });

    test('RoutineAgendaSource allows fitness routines when activeModules[sports] is true', () {
      final routines = [
        {
          'id': 'routine_fitness_1',
          'title': 'تمرین قدرتی خانگی',
          'category': 'fitness',
          'itemType': 'ROUTINE',
          'targetDurationMinutes': 45,
        },
      ];

      final schedules = routines.map((r) => {
        'routineId': r['id'],
        'scheduleType': 'FIXED_TIME',
        'timeOfDay': '08:00',
      }).toList();

      final sourceWithSportsEnabled = RoutineAgendaSource(
        routines: routines,
        schedules: schedules,
        occurrences: const [],
        avgDurations: const {},
        categoryAvgDurations: const {},
        completionsByDate: const {},
        activeModules: const {'sports': true},
      );

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 27),
        dateStr: '2026-08-27',
        isToday: true,
        prayerTimes: samplePrayerTimes,
        options: const AgendaQueryOptions(),
      );

      final items = sourceWithSportsEnabled.itemsForDate(ctx);
      expect(items.any((i) => i.title == 'تمرین قدرتی خانگی'), isTrue);
    });

    test('TaskAgendaSource itemsForDate renders overdue tasks without sports tasks when sports is disabled', () {
      final overdueTasks = [
        {
          'id': 'task_1',
          'title': 'تمرین قدرتی خانگی',
          'dueDate': '2026-08-24',
          'isDone': 0,
        },
        {
          'id': 'task_2',
          'title': 'تماس کاری',
          'dueDate': '2026-08-24',
          'isDone': 0,
        },
      ];

      final filteredOverdueTasks = overdueTasks.where((t) => t['title'] != 'تمرین قدرتی خانگی').toList();

      final source = TaskAgendaSource(
        tasksByDate: const {},
        overdueTasks: filteredOverdueTasks,
        datelessTasks: const [],
        totalOverdueCount: filteredOverdueTasks.length,
        stepCounts: const {},
      );

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 27),
        dateStr: '2026-08-27',
        isToday: true,
        prayerTimes: samplePrayerTimes,
        options: const AgendaQueryOptions(),
      );

      final items = source.itemsForDate(ctx);
      expect(items.any((i) => i.title == 'تمرین قدرتی خانگی'), isFalse);
      expect(items.any((i) => i.title == 'تماس کاری'), isTrue);
    });
  });
}
