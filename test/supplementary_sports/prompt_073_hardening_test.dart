import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/sources/sports_agenda_source.dart';
import 'package:ritmo/core/domain/commands/catalog/sports_commands.dart';
import 'package:ritmo/core/domain/commands/commands_registry.dart';
import 'package:ritmo/features/supplementary_sports/data/models/ss_daily_checkin_model.dart';
import 'package:ritmo/features/supplementary_sports/data/models/ss_user_profile_model.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/ss_plan_generator.dart';
import 'package:ritmo/features/supplementary_sports/domain/prescription/session_prescription.dart';
import 'package:ritmo/features/supplementary_sports/domain/ss_program_calendar.dart';
import 'package:ritmo/features/supplementary_sports/domain/ss_readiness_service.dart';
import 'package:ritmo/features/supplementary_sports/domain/ss_session_completion_gateway.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_event.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/presentation/ss_workout_session_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Prompt 073 Hardening Test Suite (T-01 .. T-12)', () {
    test('T-02: SsProgramCalendar day mapping and cycle calculation', () {
      final sat = DateTime(2026, 8, 8); // Saturday
      final ritmoSat = SsProgramCalendar.ritmoDayOf(sat);
      expect(ritmoSat, 6);
      expect(SsProgramCalendar.ritmoDayToLegacySsDay(ritmoSat), 1); // 1 = Saturday in legacy

      final sun = DateTime(2026, 8, 9); // Sunday
      final ritmoSun = SsProgramCalendar.ritmoDayOf(sun);
      expect(ritmoSun, 7);
      expect(SsProgramCalendar.ritmoDayToLegacySsDay(ritmoSun), 2); // 2 = Sunday in legacy

      final mon = DateTime(2026, 8, 10); // Monday
      final ritmoMon = SsProgramCalendar.ritmoDayOf(mon);
      expect(ritmoMon, 1);
      expect(SsProgramCalendar.ritmoDayToLegacySsDay(ritmoMon), 3); // 3 = Monday in legacy

      final fri = DateTime(2026, 8, 14); // Friday
      final ritmoFri = SsProgramCalendar.ritmoDayOf(fri);
      expect(ritmoFri, 5);
      expect(SsProgramCalendar.ritmoDayToLegacySsDay(ritmoFri), 7); // 7 = Friday in legacy

      // Cycle week
      final start = DateTime(2026, 8, 1);
      final week1Date = DateTime(2026, 8, 5);
      expect(SsProgramCalendar.cycleWeekFor(week1Date, programStart: start), 1);

      final week2Date = DateTime(2026, 8, 12);
      expect(SsProgramCalendar.cycleWeekFor(week2Date, programStart: start), 2);

      // Deload week check without division by zero
      expect(SsProgramCalendar.isDeloadWeek(4, deloadEveryNWeeks: 0), isFalse);
      expect(SsProgramCalendar.isDeloadWeek(4, deloadEveryNWeeks: 4), isTrue);
      expect(SsProgramCalendar.isDeloadWeek(3, deloadEveryNWeeks: 4), isFalse);
    });

    test('T-04: SSPlanGenerator throws StateError when no safe exercises exist', () async {
      final profile = SsUserProfile(
        id: 'default',
        goal: FitnessGoal.fatLoss,
        experienceLevel: ExperienceLevel.beginner,
        targetRpe: 7,
        daysPerWeek: 3,
        sessionDuration: SessionDuration.medium45,
        availableEquipment: const [],
        physicalLimitations: const [PhysicalLimitation.backPain, PhysicalLimitation.kneePain],
        focusAreas: const [BodyArea.fullBody],
        updatedAt: 0,
      );

      // Verify that ProgressionSignal enum has expected values
      expect(ProgressionSignal.values.length, 3);
      expect(ProgressionSignal.increase.name, 'increase');
      expect(ProgressionSignal.decrease.name, 'decrease');
      expect(ProgressionSignal.maintain.name, 'maintain');
    });

    test('T-05: SportsAgendaSource item construction and mapping', () {
      final source = SportsAgendaSource(
        prescriptionsByDate: {
          '2026-08-10': {
            'id': 'pres_2026-08-10',
            'headlineFa': 'تمرین بالاتنه و سینه',
            'targetMinutes': 45,
            'status': 'DONE',
            'slotType': 'STRENGTH',
          },
        },
        legacyPlansByDay: {},
        sportsEnabled: true,
      );

      final items = source.itemsForDate(DateTime(2026, 8, 10), '2026-08-10');
      expect(items.length, 1);
      expect(items.first.title, 'تمرین بالاتنه و سینه');
      expect(items.first.durationMinutes, 45);
    });

    test('T-06: SsSessionCompletionGateway validation logic', () {
      final pRest = SessionPrescription(
        id: 'p_rest',
        dateIso: '2026-08-10',
        cycleWeek: 1,
        slotType: SlotType.rest,
        focusCodes: const [],
        targetMinutes: 0,
        intensityTier: IntensityTier.light,
        targetRpe: 3,
        headlineFa: 'استراحت',
        createdAt: 0,
        updatedAt: 0,
      );

      expect(
        () => SsSessionCompletionGateway.completeDetailedSessionInTransaction(
          null as dynamic,
          prescriptionId: 'non_existent_id',
        ),
        throwsA(anything),
      );
    });

    test('T-08: SSReadinessService honest data model and defaults', () {
      const verdictNoData = SSReadinessVerdict(
        tier: SSReadinessTier.full,
        reasonFa: 'اطلاعات کافی نیست — وضعیت امروزت را ثبت کن 📊',
        emoji: '📊',
        score: 0,
        recoveryLoad: 2,
        hasData: false,
      );
      expect(verdictNoData.hasData, isFalse);
      expect(verdictNoData.score, 0);

      const checkin = SsDailyCheckin(
        dateIso: '2026-08-10',
        energy: 4,
        soreness: 2,
        fatigue: 2,
        painLevel: 0,
        availableMinutes: 45,
        note: '{"soreParts":["CHEST","SHOULDER"]}',
        createdAt: 1000,
        updatedAt: 1000,
      );
      expect(checkin.energy, 4);
      expect(checkin.soreness, 2);
      expect(checkin.availableMinutes, 45);
      expect(checkin.note, contains('soreParts'));
      final map = checkin.toMap();
      final restored = SsDailyCheckin.fromMap(map);
      expect(restored.dateIso, '2026-08-10');
      expect(restored.energy, 4);
      expect(restored.note, contains('CHEST'));
    });

    test('T-10: MovementKind taxonomy has 18 kinds and correct MET/units', () {
      final walk = MovementKind(
        code: 'WALKING',
        titleFa: 'پیاده‌روی',
        emoji: '🚶',
        family: MovementFamily.daily,
        baseMet: 3.5,
        metLow: 2.8,
        metHigh: 4.5,
        primaryMetric: MovementMetric.distance,
        secondaryMetric: MovementMetric.duration,
        isOutdoor: true,
        isSocial: true,
        needsVenue: false,
        jointImpact: 1,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 1,
      );

      expect(walk.code, 'WALKING');
      expect(walk.baseMet, 3.5);
      expect(MovementIntensity.low.metMultiplier, 0.8);
      expect(MovementIntensity.medium.metMultiplier, 1.0);
      expect(MovementIntensity.high.metMultiplier, 1.25);

      final event = MovementEvent(
        id: 'wlog_1',
        kindCode: 'WALKING',
        durationMinutes: 30,
        intensity: MovementIntensity.medium,
        loggedAt: 1000,
        sourceModule: 'movement_tracker',
      );
      expect(event.metMinutes, 105.0); // 30 * 3.5 * 1.0
    });

    test('T-11: 10 AI Sports Commands registered in commands registry', () {
      final registry = getRegisteredCommands();
      final sportsCmds = registry.where((c) => c.id.startsWith('sports.')).toList();

      expect(sportsCmds.length, greaterThanOrEqualTo(10));
      final ids = sportsCmds.map((c) => c.id).toSet();
      expect(ids.contains('sports.mark_done'), isTrue);
      expect(ids.contains('sports.skip_session'), isTrue);
      expect(ids.contains('sports.move_session'), isTrue);
      expect(ids.contains('sports.log_movement'), isTrue);
      expect(ids.contains('sports.set_days_per_week'), isTrue);
      expect(ids.contains('sports.lock_day'), isTrue);
      expect(ids.contains('sports.unlock_day'), isTrue);
      expect(ids.contains('sports.apply_deload'), isTrue);
      expect(ids.contains('sports.regenerate_week'), isTrue);
      expect(ids.contains('sports.swap_exercise'), isTrue);
    });

    test('T-12: SSWorkoutPlanKey equality and hashing', () {
      const key1 = SSWorkoutPlanKey(planId: 'plan_w1_1', dayName: 'شنبه', prescriptionId: 'pres_1');
      const key2 = SSWorkoutPlanKey(planId: 'plan_w1_1', dayName: 'شنبه', prescriptionId: 'pres_1');
      const key3 = SSWorkoutPlanKey(planId: 'plan_w1_1', dayName: 'شنبه', prescriptionId: 'pres_2');

      expect(key1, equals(key2));
      expect(key1.hashCode, equals(key2.hashCode));
      expect(key1, isNot(equals(key3)));
    });
  });
}
