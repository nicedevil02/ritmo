import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';

void main() {
  setUp(() {
    CycleClock.nowProvider = () => DateTime(2026, 5, 15);
  });

  tearDown(() {
    CycleClock.reset();
  });

  group('PregnancyProfile Tests (PRG-02)', () {
    test(
      'PregnancyProfile.fromMap({}) returns default profile without error',
      () {
        final profile = PregnancyProfile.fromMap(const {});
        expect(profile.lmpDate, equals(DateTime(2026, 5, 15)));
        expect(
          profile.dueDate,
          equals(DateTime(2026, 5, 15).add(const Duration(days: 280))),
        );
        expect(profile.eddSource, equals(PregnancyEddSource.lmp));
        expect(profile.tone, equals(PregnancyTone.warm));
        expect(profile.ageUnit, equals(PregnancyAgeUnit.weeks));
        expect(profile.isMultiple, isFalse);
        expect(profile.isHighRisk, isFalse);
        expect(profile.sectionHidden, isFalse);
        expect(profile.maskNotifications, isFalse);
        expect(profile.lockEnabled, isFalse);
        expect(profile.cycleResumeReminder, isFalse);
        expect(profile.kickTargetCount, equals(10));
        expect(profile.kickWindowMinutes, equals(120));
        expect(profile.kickBaselineComparison, isFalse);
        expect(profile.visitReminderLeadDays, equals(2));
        expect(profile.reminderHour, equals(10));
      },
    );

    test('PregnancyProfile toMap and fromMap complete roundtrip', () {
      final original = PregnancyProfile(
        lmpDate: DateTime(2026, 1, 10),
        dueDate: DateTime(2026, 10, 17),
        eddSource: PregnancyEddSource.ultrasound,
        tone: PregnancyTone.neutral,
        ageUnit: PregnancyAgeUnit.months,
        isMultiple: true,
        isHighRisk: true,
        sectionHidden: true,
        maskNotifications: true,
        lockEnabled: true,
        cycleResumeReminder: true,
        kickTargetCount: 15,
        kickWindowMinutes: 90,
        kickBaselineComparison: true,
        visitReminderLeadDays: 3,
        reminderHour: 8,
      );

      final map = original.toMap();
      final reconstructed = PregnancyProfile.fromMap(map);

      expect(reconstructed, equals(original));
      expect(
        CycleDateContract.toDayKey(reconstructed.lmpDate),
        equals('2026-01-10'),
      );
      expect(
        CycleDateContract.toDayKey(reconstructed.dueDate),
        equals('2026-10-17'),
      );
      expect(reconstructed.eddSource, equals(PregnancyEddSource.ultrasound));
      expect(reconstructed.tone, equals(PregnancyTone.neutral));
      expect(reconstructed.ageUnit, equals(PregnancyAgeUnit.months));
      expect(reconstructed.isMultiple, isTrue);
      expect(reconstructed.isHighRisk, isTrue);
      expect(reconstructed.sectionHidden, isTrue);
      expect(reconstructed.maskNotifications, isTrue);
      expect(reconstructed.lockEnabled, isTrue);
      expect(reconstructed.cycleResumeReminder, isTrue);
      expect(reconstructed.kickTargetCount, equals(15));
      expect(reconstructed.kickWindowMinutes, equals(90));
      expect(reconstructed.kickBaselineComparison, isTrue);
      expect(reconstructed.visitReminderLeadDays, equals(3));
      expect(reconstructed.reminderHour, equals(8));
    });

    test('Enums storage conversion and fallbacks', () {
      expect(PregnancyEddSource.lmp.storageValue, equals('lmp'));
      expect(PregnancyEddSource.ultrasound.storageValue, equals('ultrasound'));
      expect(PregnancyEddSource.doctorEdd.storageValue, equals('doctor_edd'));
      expect(
        PregnancyEddSource.fromStorage('ultrasound'),
        equals(PregnancyEddSource.ultrasound),
      );
      expect(
        PregnancyEddSource.fromStorage('doctor_edd'),
        equals(PregnancyEddSource.doctorEdd),
      );
      expect(
        PregnancyEddSource.fromStorage('unknown'),
        equals(PregnancyEddSource.lmp),
      );
      expect(
        PregnancyEddSource.fromStorage(null),
        equals(PregnancyEddSource.lmp),
      );

      expect(PregnancyTone.warm.storageValue, equals('warm'));
      expect(PregnancyTone.neutral.storageValue, equals('neutral'));
      expect(
        PregnancyTone.fromStorage('neutral'),
        equals(PregnancyTone.neutral),
      );
      expect(PregnancyTone.fromStorage(null), equals(PregnancyTone.warm));

      expect(PregnancyAgeUnit.weeks.storageValue, equals('weeks'));
      expect(PregnancyAgeUnit.months.storageValue, equals('months'));
      expect(
        PregnancyAgeUnit.fromStorage('months'),
        equals(PregnancyAgeUnit.months),
      );
      expect(
        PregnancyAgeUnit.fromStorage(null),
        equals(PregnancyAgeUnit.weeks),
      );
    });
  });
}
