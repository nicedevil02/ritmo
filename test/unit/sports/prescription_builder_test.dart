import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/prescription/muscle_group.dart';
import 'package:ritmo/features/supplementary_sports/domain/prescription/session_prescription.dart';
import 'package:ritmo/features/supplementary_sports/domain/sports_detail_mode.dart';

void main() {
  group(
    'Prompt 066 — Test 3: Independent Date Anchor Prescriptions (C-05)',
    () {
      test('Prescriptions with different dateIso are separate instances', () {
        const p1 = SessionPrescription(
          id: 'pres_2026-08-10',
          dateIso: '2026-08-10',
          cycleWeek: 1,
          slotType: SlotType.strength,
          focusCodes: ['CHEST', 'TRICEPS'],
          targetMinutes: 45,
          intensityTier: IntensityTier.moderate,
          headlineFa: '۴۵ دقیقه سینه و پشت‌بازو',
          source: 'GENERATED',
          createdAt: 1000,
          updatedAt: 1000,
        );

        const p2 = SessionPrescription(
          id: 'pres_2026-08-17',
          dateIso: '2026-08-17',
          cycleWeek: 2,
          slotType: SlotType.strength,
          focusCodes: ['CHEST', 'TRICEPS'],
          targetMinutes: 45,
          intensityTier: IntensityTier.moderate,
          headlineFa: '۴۵ دقیقه سینه و پشت‌بازو',
          source: 'GENERATED',
          createdAt: 1000,
          updatedAt: 1000,
        );

        expect(p1.dateIso, isNot(equals(p2.dateIso)));
        final completedP1 = p1.copyWith(
          status: PrescriptionStatus.done,
          workoutLogId: 'wlog_1',
        );
        expect(completedP1.status, equals(PrescriptionStatus.done));
        expect(p2.status, equals(PrescriptionStatus.planned));
      });
    },
  );

  group('Prompt 066 — Test 4: Prescription Serialization (C-06)', () {
    test(
      'SessionPrescription.toMap and fromMap perform lossless roundtrip',
      () {
        const p = SessionPrescription(
          id: 'pres_test_1',
          dateIso: '2026-08-10',
          cycleWeek: 1,
          slotType: SlotType.strength,
          focusCodes: ['CHEST', 'SHOULDER'],
          targetMinutes: 60,
          intensityTier: IntensityTier.hard,
          targetRpe: 8,
          headlineFa: '۶۰ دقیقه سینه و سرشانه',
          coachNoteFa: 'تمرین با کیفیت امروز',
          source: 'USER',
          isLocked: true,
          status: PrescriptionStatus.done,
          workoutLogId: 'wlog_123',
          createdAt: 1000,
          updatedAt: 2000,
        );

        final map = p.toMap();
        final restored = SessionPrescription.fromMap(map);

        expect(restored.id, equals(p.id));
        expect(restored.dateIso, equals(p.dateIso));
        expect(restored.slotType, equals(p.slotType));
        expect(restored.focusCodes, equals(p.focusCodes));
        expect(restored.targetMinutes, equals(p.targetMinutes));
        expect(restored.intensityTier, equals(p.intensityTier));
        expect(restored.isLocked, isTrue);
        expect(restored.status, equals(PrescriptionStatus.done));
        expect(restored.workoutLogId, equals('wlog_123'));
      },
    );
  });

  group(
    'Prompt 066 — Test 5 & 6: Headline Builder and Persian Digits (C-09)',
    () {
      test(
        'buildHeadline produces Persian digits for minutes and joins muscle groups',
        () {
          final headline = MuscleGroup.buildHeadline(45, [
            'BICEPS',
            'SHOULDER',
          ], SlotType.strength);

          expect(headline, contains('۴۵'));
          expect(headline, contains('دقیقه'));
          expect(headline, contains('جلوبازو'));
          expect(headline, contains('سرشانه'));
        },
      );

      test(
        'buildHeadline with >3 muscle groups resolves to FULL_BODY (کل بدن)',
        () {
          final headline = MuscleGroup.buildHeadline(60, [
            'CHEST',
            'SHOULDER',
            'BICEPS',
            'TRICEPS',
          ], SlotType.strength);

          expect(headline, contains('۶۰'));
          expect(headline, contains('دقیقه'));
          expect(headline, contains('کل بدن'));
        },
      );

      test('buildHeadline for REST returns "استراحت"', () {
        final headline = MuscleGroup.buildHeadline(0, const [], SlotType.rest);
        expect(headline, equals('استراحت'));
      });
    },
  );

  group('Prompt 066 — Test 7: Locked Prescriptions Protection', () {
    test('copyWith isLocked toggles lock status', () {
      const p = SessionPrescription(
        id: 'pres_lock_1',
        dateIso: '2026-08-10',
        cycleWeek: 1,
        slotType: SlotType.strength,
        focusCodes: ['CHEST'],
        targetMinutes: 45,
        intensityTier: IntensityTier.moderate,
        headlineFa: '۴۵ دقیقه سینه',
        source: 'USER',
        isLocked: true,
        createdAt: 1000,
        updatedAt: 1000,
      );

      expect(p.isLocked, isTrue);
      final unlocked = p.copyWith(isLocked: false);
      expect(unlocked.isLocked, isFalse);
    });
  });

  group('Prompt 066 — Test 10: SportsDetailMode Gating', () {
    test('SportsDetailMode notifier starts as false', () {
      expect(SportsDetailMode.notifier.value, isFalse);
    });
  });
}
