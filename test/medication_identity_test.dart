import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/routine_agenda_source.dart';
import 'package:ritmo/core/domain/medication/medication_identity.dart';

/// A row exactly as sqflite returns it for an ordinary routine.
Map<String, dynamic> plainRoutineRow({Map<String, dynamic> overrides = const {}}) {
  return <String, dynamic>{
    'id': 'onboarding_routine_water_habit',
    'title': 'نوشیدن آب',
    'category': 'personal',
    'itemType': 'ROUTINE',
    'isArchived': 0,
    'medStockCount': 0,
    'medRefillThreshold': 0,
    'minIntervalHours': 0,
    'maxDosesPerDay': 0,
    ...overrides,
  };
}

void main() {
  group('MedicationIdentity.isMedicationRoutine', () {
    test('a plain routine with zeroed medication columns is not a medication', () {
      expect(MedicationIdentity.isMedicationRoutine(plainRoutineRow()), isFalse);
    });

    test('zeros stored as text are still not a medication', () {
      final row = plainRoutineRow(overrides: {
        'medStockCount': '0',
        'maxDosesPerDay': '0',
      });
      expect(MedicationIdentity.isMedicationRoutine(row), isFalse);
    });

    test('missing medication columns are not a medication', () {
      final row = plainRoutineRow()
        ..remove('medStockCount')
        ..remove('medRefillThreshold')
        ..remove('minIntervalHours')
        ..remove('maxDosesPerDay');
      expect(MedicationIdentity.isMedicationRoutine(row), isFalse);
    });

    test('every onboarding starter routine stays a routine', () {
      const starterIds = <String>[
        'onboarding_routine_water_habit',
        'onboarding_routine_morning_stretch',
        'onboarding_routine_focus_reading',
        'onboarding_routine_daily_planning',
        'onboarding_routine_night_winddown',
        'onboarding_routine_family_checkin',
        'onboarding_routine_quiet_reflection',
      ];
      for (final id in starterIds) {
        final row = plainRoutineRow(overrides: {'id': id});
        expect(
          MedicationIdentity.isMedicationRoutine(row),
          isFalse,
          reason: '$id must not be classified as a medication',
        );
      }
    });

    test('the canonical itemType marks a medication', () {
      final row = plainRoutineRow(overrides: {'itemType': MedicationIdentity.itemType});
      expect(MedicationIdentity.isMedicationRoutine(row), isTrue);
    });

    test('explicit non-medication itemTypes (ROUTINE, EVENT, TASK) NEVER guess via columns', () {
      for (final type in ['ROUTINE', 'EVENT', 'TASK', 'REMINDER', 'REFLECT']) {
        final row = plainRoutineRow(overrides: {
          'itemType': type,
          'medStockCount': 30,
          'minIntervalHours': 4,
          'maxDosesPerDay': 3,
        });
        expect(
          MedicationIdentity.isMedicationRoutine(row),
          isFalse,
          reason: 'Explicit itemType $type must never evaluate column heuristics',
        );
      }
    });

    test('legacy rows (itemType is null or empty) use id prefix and column heuristics', () {
      // Legacy id prefix
      final legacyIdRow = plainRoutineRow(overrides: {
        'itemType': null,
        'id': '${MedicationIdentity.routineIdPrefix}vitamin_d',
      });
      expect(MedicationIdentity.isMedicationRoutine(legacyIdRow), isTrue);

      // Legacy positive columns
      for (final column in MedicationIdentity.medicationColumns) {
        final legacyColRow = plainRoutineRow(overrides: {
          'itemType': null,
          column: 2,
        });
        expect(
          MedicationIdentity.isMedicationRoutine(legacyColRow),
          isTrue,
          reason: 'Legacy row with positive $column must be classified as medication',
        );
      }

      // Legacy row stored as positive text
      final legacyTextRow = plainRoutineRow(overrides: {
        'itemType': '',
        'medStockCount': '30',
      });
      expect(MedicationIdentity.isMedicationRoutine(legacyTextRow), isTrue);

      // Legacy row with zeroed columns is not a medication
      final legacyZeroRow = plainRoutineRow(overrides: {
        'itemType': null,
        'medStockCount': 0,
      });
      expect(MedicationIdentity.isMedicationRoutine(legacyZeroRow), isFalse);
    });
  });

  group('MedicationIdentity.sqlPredicate', () {
    test('stays the twin of the in-memory predicate', () {
      expect(
        MedicationIdentity.sqlPredicate.contains('IS NOT NULL'),
        isFalse,
        reason: 'NOT NULL DEFAULT 0 columns make a null check match every row',
      );
      for (final column in MedicationIdentity.medicationColumns) {
        expect(
          MedicationIdentity.sqlPredicate.contains('COALESCE($column, 0) > 0'),
          isTrue,
          reason: '$column must be compared against zero in legacy check',
        );
      }
      expect(MedicationIdentity.sqlPredicate.contains("itemType = 'MEDICINE'"), isTrue);
      expect(MedicationIdentity.sqlPredicate.contains("id LIKE 'routine_med_%'"), isTrue);
    });
  });

  group('MedicationIdentity.isAsNeeded', () {
    test('only the asNeeded routine type is PRN', () {
      expect(
        MedicationIdentity.isAsNeeded(
          plainRoutineRow(overrides: {'routineType': MedicationIdentity.asNeededRoutineType}),
        ),
        isTrue,
      );
      expect(
        MedicationIdentity.isAsNeeded(plainRoutineRow(overrides: {'routineType': 'daily'})),
        isFalse,
      );
    });
  });

  group('Planner vs Medication Regression Tests', () {
    test('event or task created from generic planner is never recognized as medication', () {
      final plannerEvent = <String, dynamic>{
        'id': 'routine_event_meeting_123',
        'title': 'جلسه کاری',
        'category': 'work',
        'itemType': 'EVENT',
        'isArchived': 0,
        'minIntervalHours': 4, // GenericStrategy default context
        'maxDosesPerDay': 4,   // GenericStrategy default context
      };
      expect(MedicationIdentity.isMedicationRoutine(plannerEvent), isFalse);

      final plannerTask = <String, dynamic>{
        'id': 'routine_task_report_456',
        'title': 'ارسال گزارش',
        'category': 'work',
        'itemType': 'TASK',
        'isArchived': 0,
        'minIntervalHours': 4,
        'maxDosesPerDay': 4,
      };
      expect(MedicationIdentity.isMedicationRoutine(plannerTask), isFalse);
    });

    test('medication is not rendered in RoutineAgendaSource when medicine domain is active', () {
      final medRoutine = <String, dynamic>{
        'id': 'routine_med_aspirin',
        'title': 'آسپرین',
        'category': 'medical',
        'itemType': 'MEDICINE',
        'isArchived': 0,
        'medStockCount': 30,
        'medRefillThreshold': 5,
        'minIntervalHours': 0,
        'maxDosesPerDay': 0,
      };
      final schedule = <String, dynamic>{
        'id': 'sched_routine_med_aspirin',
        'routineId': 'routine_med_aspirin',
        'timeOfDay': '08:00',
        'daysOfWeek': '6,7,1,2,3,4,5',
      };

      final source = RoutineAgendaSource(
        routines: [medRoutine],
        schedules: [schedule],
        occurrences: const [],
        avgDurations: const {},
        categoryAvgDurations: const {},
        completionsByDate: const {},
        activeModules: const {'medicine': true},
      );

      final date = DateTime(2026, 8, 17);
      final ctx = AgendaDayContext(
        date: date,
        dateStr: '2026-08-17',
        isToday: true,
        options: const AgendaQueryOptions(domains: {AgendaDomain.routine, AgendaDomain.medicine}),
        prayerTimes: const {},
      );

      final items = source.itemsForDate(ctx);
      expect(items.where((it) => it.sourceId == 'routine_med_aspirin'), isEmpty,
          reason: 'Medication must not be rendered in RoutineAgendaSource when MedicineAgendaSource owns it');
    });
  });
}
