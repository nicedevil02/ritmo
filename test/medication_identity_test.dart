import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/medication/medication_identity.dart';

/// A row exactly as sqflite returns it for an ordinary routine.
///
/// `routines` declares medStockCount / medRefillThreshold / minIntervalHours /
/// maxDosesPerDay as `INTEGER NOT NULL DEFAULT 0`, so these keys are always
/// present and never null. That is what broke the Calendar: a `!= null` check
/// matched every routine, so RoutineAgendaSource treated all of them as
/// medications and emitted zero items while the routine list stayed full.
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

    test('the minted id prefix marks a medication', () {
      final row = plainRoutineRow(overrides: {'id': '${MedicationIdentity.routineIdPrefix}vitamin_d'});
      expect(MedicationIdentity.isMedicationRoutine(row), isTrue);
    });

    test('a positive medication column marks a medication', () {
      for (final column in MedicationIdentity.medicationColumns) {
        final row = plainRoutineRow(overrides: {column: 2});
        expect(
          MedicationIdentity.isMedicationRoutine(row),
          isTrue,
          reason: 'a positive $column must identify a medication',
        );
      }
    });

    test('a positive column stored as text marks a medication', () {
      final row = plainRoutineRow(overrides: {'medStockCount': '30'});
      expect(MedicationIdentity.isMedicationRoutine(row), isTrue);
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
          reason: '$column must be compared against zero',
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
}
