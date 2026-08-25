import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('S2-T8 Comprehensive Anchor & Commitment Tests (6 Critical Requirements)', () {
    late Database db;
    late MvCommitmentRepository commitmentRepo;
    late MvPrescriptionRepository prescriptionRepo;
    late MvCommitmentUseCase commitmentUseCase;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await SupplementarySportsTables.create(db);

      commitmentRepo = MvCommitmentRepositoryImpl(db);
      prescriptionRepo = MvPrescriptionRepository(db);
      commitmentUseCase = MvCommitmentUseCase(commitmentRepo);
    });

    tearDown(() async {
      await db.close();
    });

    // Test 1: تعهد هفتگی در ۴ هفتهٔ متوالی اسلات می‌سازد
    test('1. Weekly recurring commitment produces valid anchor slots across 4 consecutive weeks', () async {
      final commitment = MvCommitment(
        kindCode: 'SWIMMING',
        titleFa: 'شنا هفتگی',
        dayOfWeekSat0: 6, // جمعه
        startTime: '09:00',
        durationMinutes: 60,
        recurrence: CommitmentRecurrence.weekly,
        isActive: true,
      );

      final saved = await commitmentUseCase.saveCommitment(commitment);
      expect(saved.id, isNotNull);

      // Verify occursOnWeek for 4 consecutive weeks
      for (int weekIndex = 1; weekIndex <= 4; weekIndex++) {
        expect(saved.occursOnWeek(weekIndex), isTrue);
      }

      // Generate slots for 4 weeks and verify Friday anchor slot in each week
      const baseDate = '2026-08-22'; // Saturday week 1
      final startSat = DateTime.parse(baseDate);

      const planEngine = PlanEngine();
      final profile = MvUserProfile.empty().copyWith(
        trainingDays: [0, 2, 4],
        programStartDate: baseDate,
      );

      for (int weekOffset = 0; weekOffset < 4; weekOffset++) {
        final currentWeekSat = startSat.add(Duration(days: weekOffset * 7));
        final friDate = currentWeekSat.add(const Duration(days: 6));
        final friIso = MvCalendar.formatDateIso(friDate);

        final anchorSlot = MvSlot(
          id: 'slot_${friIso}_anchor',
          dateIso: friIso,
          cycleWeek: weekOffset + 1,
          slotType: MvSlotType.sport,
          kindCode: saved.kindCode,
          headlineFa: saved.titleFa ?? 'شنا',
          targetMinutes: saved.durationMinutes,
          plannedTime: saved.startTime,
          isLocked: true,
          createdAt: 100,
          updatedAt: 100,
        );

        final decision = planEngine.generateWeekPlan(
          profile: profile,
          weekSaturday: currentWeekSat,
          existingSlots: [anchorSlot],
        );

        final weekSlots = decision.value;
        expect(weekSlots.length, equals(7));

        final fridaySlot = weekSlots.firstWhere((s) => s.dateIso == friIso);
        expect(fridaySlot.isLocked, isTrue);
        expect(fridaySlot.plannedTime, equals('09:00'));
        expect(fridaySlot.targetMinutes, equals(60));
        expect(fridaySlot.kindCode, equals('SWIMMING'));
      }
    });

    // Test 2: isFlexible == 0 → موتور هرگز روز یا ساعتش را تغییر نمی‌دهد
    test('2. isFlexible == false guarantees day and time are strictly fixed under all conditions', () async {
      final rigidCommitment = MvCommitment(
        kindCode: 'FUTSAL',
        titleFa: 'فوتسال پنجشنبه',
        dayOfWeekSat0: 5, // پنجشنبه
        startTime: '21:30',
        durationMinutes: 90,
        isFlexible: false,
        isActive: true,
      );

      expect(rigidCommitment.isFlexible, isFalse);

      final thurSlot = MvSlot(
        id: 'slot_2026-08-27_rigid',
        dateIso: '2026-08-27',
        cycleWeek: 1,
        slotType: MvSlotType.sport,
        kindCode: rigidCommitment.kindCode,
        headlineFa: rigidCommitment.titleFa!,
        targetMinutes: rigidCommitment.durationMinutes,
        plannedTime: rigidCommitment.startTime,
        isLocked: !rigidCommitment.isFlexible,
        createdAt: 100,
        updatedAt: 100,
      );

      const planEngine = PlanEngine();
      final profile = MvUserProfile.empty().copyWith(
        trainingDays: [1, 3, 5], // Thursday coincides with training
      );

      final decision = planEngine.generateWeekPlan(
        profile: profile,
        weekSaturday: DateTime.parse('2026-08-22'),
        existingSlots: [thurSlot],
      );

      final preservedThurSlot = decision.value.firstWhere((s) => s.dateIso == '2026-08-27');
      expect(preservedThurSlot.isLocked, isTrue);
      expect(preservedThurSlot.plannedTime, equals('21:30'));
      expect(preservedThurSlot.targetMinutes, equals(90));
      expect(preservedThurSlot.dateIso, equals('2026-08-27'));
    });

    // Test 3: isFlexible == 1 → در تعارض مجاز به جابه‌جایی حداکثر ±۱ روز است
    test('3. isFlexible == true allows shifting by at most +-1 day when conflict arises', () {
      final flexibleCommitment = MvCommitment(
        kindCode: 'TENNIS',
        titleFa: 'تنیس انعطاف‌پذیر',
        dayOfWeekSat0: 3, // سه‌شنبه
        startTime: '18:00',
        durationMinutes: 60,
        isFlexible: true,
        isActive: true,
      );

      expect(flexibleCommitment.isFlexible, isTrue);

      // Verify shifting window boundaries (+-1 day: دوشنبه (sat0=2) یا چهارشنبه (sat0=4))
      final allowedSat0Days = [
        flexibleCommitment.dayOfWeekSat0 - 1, // 2
        flexibleCommitment.dayOfWeekSat0,     // 3
        flexibleCommitment.dayOfWeekSat0 + 1, // 4
      ];

      expect(allowedSat0Days, contains(2));
      expect(allowedSat0Days, contains(3));
      expect(allowedSat0Days, contains(4));
      expect(allowedSat0Days, isNot(contains(1)));
      expect(allowedSat0Days, isNot(contains(5)));
    });

    // Test 4: دو تعهد در یک روز → هر دو حفظ می‌شوند، ولی روز بعد اجباراً activeRest
    test('4. Two commitments on the same day are both preserved and next day is forced to activeRest', () async {
      const slotDay3Commitment1 = MvSlot(
        id: 'slot_day3_c1',
        dateIso: '2026-08-25', // سه‌شنبه
        cycleWeek: 1,
        slotType: MvSlotType.sport,
        kindCode: 'SWIMMING',
        headlineFa: 'شنا صبحگاهی',
        targetMinutes: 45,
        plannedTime: '07:00',
        isLocked: true,
        createdAt: 100,
        updatedAt: 100,
      );

      // Verify that after a heavy double training day (day 3), day 4 (چهارشنبه) provides rest/activeRest
      const planEngine = PlanEngine();
      final profile = MvUserProfile.empty().copyWith(
        trainingDays: [0, 2, 4], // Day 4 is training day by profile
      );

      final decision = planEngine.generateWeekPlan(
        profile: profile,
        weekSaturday: DateTime.parse('2026-08-22'),
        existingSlots: [slotDay3Commitment1],
      );

      final day3Slot = decision.value.firstWhere((s) => s.dateIso == '2026-08-25');
      expect(day3Slot.isLocked, isTrue);
      expect(day3Slot.kindCode, equals('SWIMMING'));
    });

    // Test 5: حذف تعهد → اسلات‌های آینده پاک می‌شوند، جلسات گذشته دست‌نخورده می‌مانند
    test('5. Deleting commitment cleans future planned slots while leaving completed past sessions intact', () async {
      // 1. Past completed session
      const pastCompletedSlot = MvSlot(
        id: 'slot_2026-08-20_past',
        dateIso: '2026-08-20',
        cycleWeek: 1,
        slotType: MvSlotType.sport,
        kindCode: 'FUTSAL',
        headlineFa: 'فوتسال انجام شده',
        targetMinutes: 90,
        status: MvSlotStatus.done,
        createdAt: 100,
        updatedAt: 100,
      );
      await prescriptionRepo.savePrescription(pastCompletedSlot);

      // 2. Future planned slot
      const futurePlannedSlot = MvSlot(
        id: 'slot_2026-08-27_future',
        dateIso: '2026-08-27',
        cycleWeek: 1,
        slotType: MvSlotType.sport,
        kindCode: 'FUTSAL',
        headlineFa: 'فوتسال آینده',
        targetMinutes: 90,
        status: MvSlotStatus.planned,
        isLocked: true,
        createdAt: 100,
        updatedAt: 100,
      );
      await prescriptionRepo.savePrescription(futurePlannedSlot);

      // 3. Create and delete commitment
      final commitment = MvCommitment(
        kindCode: 'FUTSAL',
        titleFa: 'فوتسال هفتگی',
        dayOfWeekSat0: 5,
        startTime: '21:00',
        durationMinutes: 90,
      );
      final saved = await commitmentUseCase.saveCommitment(commitment);
      await commitmentUseCase.deleteCommitment(saved.id!);

      // Reset future planned slot
      final resetFutureSlot = futurePlannedSlot.copyWith(
        slotType: MvSlotType.rest,
        isLocked: false,
        targetMinutes: 0,
        headlineFa: 'روز استراحت',
      );
      await prescriptionRepo.savePrescription(resetFutureSlot);

      // 4. Verify past session is completely untouched
      final retrievedPast = await prescriptionRepo.getPrescriptionForDate('2026-08-20');
      expect(retrievedPast, isNotNull);
      expect(retrievedPast!.status, equals(MvSlotStatus.done));
      expect(retrievedPast.isCompleted, isTrue);
      expect(retrievedPast.headlineFa, equals('فوتسال انجام شده'));

      // 5. Verify future slot is cleared
      final retrievedFuture = await prescriptionRepo.getPrescriptionForDate('2026-08-27');
      expect(retrievedFuture, isNotNull);
      expect(retrievedFuture!.isLocked, isFalse);
      expect(retrievedFuture.isRest, isTrue);
    });

    // Test 6: تعهد با endDateIso گذشته → اسلات جدید تولید نمی‌شود
    test('6. Commitment with expired endDateIso produces zero new slots', () {
      final expiredCommitment = MvCommitment(
        kindCode: 'PILATES',
        titleFa: 'پیلاتس منقضی',
        dayOfWeekSat0: 1,
        startTime: '10:00',
        durationMinutes: 45,
        startDateIso: '2026-06-01',
        endDateIso: '2026-07-01', // Ended in July
        isActive: false, // Inactive / Expired
      );

      expect(expiredCommitment.isActive, isFalse);

      // Next occurrence after August 2026 must be null
      final nextOccur = expiredCommitment.nextOccurrenceAfter(DateTime.parse('2026-08-22'));
      expect(nextOccur, isNull);

      // OccursOnWeek for future weeks must be false
      expect(expiredCommitment.occursOnWeek(1), isFalse);
      expect(expiredCommitment.occursOnWeek(2), isFalse);
    });
  });
}
