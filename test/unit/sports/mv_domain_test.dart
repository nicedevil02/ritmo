import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('MvCalendar Tests (P1 Domain)', () {
    test(
      'sat0ToDartWeekday and dartWeekdayToSat0 roundtrip for all 7 days',
      () {
        for (int sat0 = 0; sat0 <= 6; sat0++) {
          final dartWeekday = MvCalendar.sat0ToDartWeekday(sat0);
          final backToSat0 = MvCalendar.dartWeekdayToSat0(dartWeekday);
          expect(backToSat0, equals(sat0));
        }
      },
    );

    test('dateTimeToSat0 returns correct Sat0 index', () {
      // 2026-08-22 is a Saturday (Sat0 = 0)
      final sat = DateTime(2026, 8, 22);
      expect(MvCalendar.dateTimeToSat0(sat), equals(0));

      // 2026-08-23 is a Sunday (Sat0 = 1)
      final sun = DateTime(2026, 8, 23);
      expect(MvCalendar.dateTimeToSat0(sun), equals(1));

      // 2026-08-28 is a Friday (Sat0 = 6)
      final fri = DateTime(2026, 8, 28);
      expect(MvCalendar.dateTimeToSat0(fri), equals(6));
    });

    test('formatDateIso and parseDateIso roundtrip correctly', () {
      final dt = DateTime(2026, 8, 25);
      final iso = MvCalendar.formatDateIso(dt);
      expect(iso, equals('2026-08-25'));
      final parsed = MvCalendar.parseDateIso(iso);
      expect(parsed.year, equals(2026));
      expect(parsed.month, equals(8));
      expect(parsed.day, equals(25));
    });

    test('getWeekDays returns 7 consecutive days starting from Saturday', () {
      final midWeek = DateTime(2026, 8, 25); // Tuesday
      final weekDays = MvCalendar.getWeekDays(midWeek);
      expect(weekDays.length, equals(7));
      expect(MvCalendar.dateTimeToSat0(weekDays.first), equals(0)); // Saturday
      expect(MvCalendar.dateTimeToSat0(weekDays.last), equals(6)); // Friday
    });

    test('cycleWeekFor and isDeloadWeek calculations', () {
      final start = DateTime(2026, 8, 1);
      final week1 = DateTime(2026, 8, 3);
      final week4 = DateTime(2026, 8, 24);

      expect(
        MvCalendar.cycleWeekFor(
          targetDate: week1,
          programStartDate: start,
          totalWeeks: 4,
        ),
        equals(1),
      );
      expect(
        MvCalendar.cycleWeekFor(
          targetDate: week4,
          programStartDate: start,
          totalWeeks: 4,
        ),
        equals(4),
      );

      expect(MvCalendar.isDeloadWeek(1, deloadEveryNWeeks: 4), isFalse);
      expect(MvCalendar.isDeloadWeek(4, deloadEveryNWeeks: 4), isTrue);
    });

    test('persianWeekdayName returns correct Persian names', () {
      expect(MvCalendar.persianWeekdayName(0), equals('شنبه'));
      expect(MvCalendar.persianWeekdayName(6), equals('جمعه'));
      expect(MvCalendar.persianWeekdayShort(0), equals('ش'));
      expect(MvCalendar.persianWeekdayShort(6), equals('ج'));
    });
  });

  group('MvSlot Model Tests', () {
    test('toMap and fromMap preserves all fields', () {
      const slot = MvSlot(
        id: 'slot_123',
        dateIso: '2026-08-25',
        cycleWeek: 2,
        slotType: MvSlotType.strength,
        kindCode: 'bodyweight',
        routineId: 'rout_456',
        plannedTime: '08:30',
        focusCodes: ['CHEST', 'TRICEPS'],
        targetMinutes: 45,
        intensityTier: MvIntensityTier.hard,
        targetRpe: 8,
        actualRpe: 7,
        headlineFa: 'قدرت بالاتنه',
        coachNoteFa: 'گرم کردن فراموش نشود',
        source: 'GENERATED',
        isLocked: true,
        status: MvSlotStatus.done,
        createdAt: 1000,
        updatedAt: 2000,
      );

      final map = slot.toMap();
      final restored = MvSlot.fromMap(map);

      expect(restored.id, equals(slot.id));
      expect(restored.dateIso, equals(slot.dateIso));
      expect(restored.cycleWeek, equals(slot.cycleWeek));
      expect(restored.slotType, equals(slot.slotType));
      expect(restored.kindCode, equals(slot.kindCode));
      expect(restored.routineId, equals(slot.routineId));
      expect(restored.plannedTime, equals(slot.plannedTime));
      expect(restored.focusCodes, equals(slot.focusCodes));
      expect(restored.targetMinutes, equals(slot.targetMinutes));
      expect(restored.intensityTier, equals(slot.intensityTier));
      expect(restored.targetRpe, equals(slot.targetRpe));
      expect(restored.actualRpe, equals(slot.actualRpe));
      expect(restored.headlineFa, equals(slot.headlineFa));
      expect(restored.coachNoteFa, equals(slot.coachNoteFa));
      expect(restored.isLocked, isTrue);
      expect(restored.isCompleted, isTrue);
    });

    test('copyWith updates specific fields properly', () {
      const slot = MvSlot(
        id: 'slot_1',
        dateIso: '2026-08-25',
        headlineFa: 'تمرین',
        createdAt: 100,
        updatedAt: 100,
      );

      final updated = slot.copyWith(
        status: MvSlotStatus.skipped,
        headlineFa: 'استراحت',
      );

      expect(updated.id, equals('slot_1'));
      expect(updated.status, equals(MvSlotStatus.skipped));
      expect(updated.isSkipped, isTrue);
      expect(updated.headlineFa, equals('استراحت'));
    });
  });

  group('MvSession and MvSessionEvent Tests', () {
    test('MvSession elapsed time calculation', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final session = MvSession(
        id: 'sess_1',
        kindCode: 'running',
        sessionMode: MvSessionMode.distance,
        status: MvSessionStatus.active,
        startedAt: now - 600000, // 10 minutes ago
        pausedMs: 60000, // 1 min paused
        createdAt: now - 600000,
        updatedAt: now,
      );

      // net should be ~9 minutes = 540000 ms
      expect(session.elapsedMinutes, equals(9));
      expect(session.isActive, isTrue);
    });

    test('MvSessionEvent serialization roundtrip', () {
      const event = MvSessionEvent(
        id: 'evt_1',
        sessionId: 'sess_1',
        type: 'SET_COMPLETE',
        at: 123456789,
        dataJson: '{"setIndex": 1}',
      );

      final map = event.toMap();
      final restored = MvSessionEvent.fromMap(map);

      expect(restored.id, equals(event.id));
      expect(restored.sessionId, equals(event.sessionId));
      expect(restored.type, equals(event.type));
      expect(restored.at, equals(event.at));
      expect(restored.dataJson, equals(event.dataJson));
    });
  });

  group('MvUserProfile and MvDecision Tests', () {
    test('MvUserProfile empty defaults and serialization', () {
      final profile = MvUserProfile.empty();
      expect(profile.daysPerWeek, equals(3));
      expect(profile.trainingDays, equals([0, 2, 4]));
      expect(profile.onboardingCompleted, isFalse);

      final map = profile.toMap();
      final restored = MvUserProfile.fromMap(map);
      expect(restored.id, equals('default'));
      expect(restored.daysPerWeek, equals(3));
    });

    test('MvDecision map and explainability structure', () {
      const decision = MvDecision<int>(
        value: 10,
        reasonFa: 'به خاطر خواب کم دیشب',
        sources: ['sleep', 'checkin'],
        confidence: 0.85,
        hasEnoughData: true,
      );

      expect(decision.value, equals(10));
      expect(decision.reasonFa, equals('به خاطر خواب کم دیشب'));
      expect(decision.sources, contains('sleep'));

      final mapped = decision.map((v) => 'Value: $v');
      expect(mapped.value, equals('Value: 10'));
      expect(mapped.reasonFa, equals(decision.reasonFa));
    });
  });

  group('Muscle Groups and Exercises', () {
    test('12 Standard Muscle Groups exist with correct codes', () {
      expect(MvMuscleGroup.all.length, equals(12));
      expect(MvMuscleGroup.findByCode('CHEST')?.titleFa, equals('سینه'));
      expect(MvMuscleGroup.findByCode('CORE')?.emoji, equals('🎽'));
      expect(MvMuscleGroup.findByCode('NON_EXISTENT'), isNull);
    });

    test('MvExercise time-based and animation getters', () {
      const exercise = MvExercise(
        id: 'ex_1',
        name: 'شنا سوئدی',
        category: 'chest',
        durationSeconds: 0,
        defaultReps: 12,
        animationAsset: 'assets/animations/custom/hw_push_up.json',
      );

      expect(exercise.isTimeBased, isFalse);
      expect(exercise.hasAnimation, isTrue);
    });
  });
}
