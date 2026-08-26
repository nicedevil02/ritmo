import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/rie/context_snapshot.dart';
import 'package:ritmo/core/domain/engines/rie/rie_filters.dart';
import 'package:ritmo/core/domain/engines/rie/rie_scorers.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/domain/models/daily_behavior.dart';
import 'package:ritmo/core/domain/realm/realm_mode.dart';

void main() {
  group('ZoneAndEssentialFilter & RIE Rules (B-02, B-10, B-11, B-13)', () {
    const filter = ZoneAndEssentialFilter();

    final normalRoutine = Routine(
      id: 'r_normal',
      title: 'ورزش عصرگاهی',
      category: Category.fitness,
      routineType: RoutineType.timeBased,
      notificationLevel: NotificationLevel.normal,
      isEssential: false,
      energyRule: EnergyRule.none,
    );

    final workTask = Routine(
      id: 'r_work',
      title: 'ارسال ایمیل کاری',
      category: Category.work,
      routineType: RoutineType.timeBased,
      notificationLevel: NotificationLevel.normal,
      isEssential: false,
      energyRule: EnergyRule.none,
    );

    final essentialWorkRoutine = Routine(
      id: 'r_work_essential',
      title: 'جلسه هیئت مدیره',
      category: Category.work,
      routineType: RoutineType.timeBased,
      notificationLevel: NotificationLevel.important,
      isEssential: true,
      energyRule: EnergyRule.none,
    );

    final essentialMedicalRoutine = Routine(
      id: 'r_med_essential',
      title: 'انسولین شبانه',
      category: Category.medical,
      routineType: RoutineType.timeBased,
      notificationLevel: NotificationLevel.important,
      isEssential: true,
      energyRule: EnergyRule.none,
    );

    ContextSnapshot buildSnapshot({
      RealmMode mode = RealmMode.normal,
      String? activeZoneId,
      Set<String> blockedRoutineIds = const {},
      Set<String> boostedRoutineIds = const {},
    }) {
      return ContextSnapshot(
        now: DateTime(2026, 8, 26, 12, 0),
        appSettings: const {},
        activeZoneId: activeZoneId,
        activeRealmMode: mode,
        currentEnergy: EnergyLevel.medium,
        isMenstruating: false,
        dailyBehavior: DailyBehavior(
          context: LifeContext.normal,
          behavior: 'NORMAL',
        ),
        blockedRoutineIdsInZone: blockedRoutineIds,
        boostedRoutineIdsInZone: boostedRoutineIds,
        completedRoutineIdsToday: const {},
        routineSchedulesByRoutineId: const {},
        enteredRoutines: const [],
      );
    }

    test('1. NORMAL realm mode lets all non-blocked routines pass', () {
      final snapshot = buildSnapshot(mode: RealmMode.normal);
      final visible = filter.filter([normalRoutine, workTask, essentialWorkRoutine], snapshot);
      expect(visible.length, 3);
    });

    test('2. FOCUS and SILENT realm modes suppress non-essential routines (B-02, B-10)', () {
      final focusSnapshot = buildSnapshot(mode: RealmMode.focus);
      final silentSnapshot = buildSnapshot(mode: RealmMode.silent);

      final focusVisible = filter.filter([normalRoutine, workTask, essentialWorkRoutine], focusSnapshot);
      expect(focusVisible.map((r) => r.id), ['r_work_essential']);

      final silentVisible = filter.filter([normalRoutine, workTask, essentialWorkRoutine], silentSnapshot);
      expect(silentVisible.map((r) => r.id), ['r_work_essential']);
    });

    test('3. Explicit user BLOCKED rule takes precedence over isEssential for non-medical routines (B-11)', () {
      // User explicitly blocked 'r_work_essential' in family realm
      final snapshot = buildSnapshot(
        mode: RealmMode.normal,
        activeZoneId: 'family',
        blockedRoutineIds: {'r_work_essential'},
      );

      final visible = filter.filter([normalRoutine, essentialWorkRoutine], snapshot);
      // 'r_work_essential' must be BLOCKED because user explicit rule is paramount!
      expect(visible.map((r) => r.id), ['r_normal']);
    });

    test('4. Safety Exception: Critical Medical (Category.medical && isEssential) always passes explicit block (B-11)', () {
      // Even if user accidentally blocked insulin, critical medicine must never be suppressed
      final snapshot = buildSnapshot(
        mode: RealmMode.silent,
        activeZoneId: 'focus_zone',
        blockedRoutineIds: {'r_med_essential', 'r_work_essential'},
      );

      final visible = filter.filter([essentialWorkRoutine, essentialMedicalRoutine], snapshot);
      expect(visible.map((r) => r.id), ['r_med_essential']);
    });

    test('5. ZoneMatchScorer boosts routines with BOOSTED rule by 1.5 score (B-13)', () {
      const scorer = ZoneMatchScorer();
      final snapshot = buildSnapshot(
        activeZoneId: 'work_zone',
        boostedRoutineIds: {'r_work'},
      );

      final normalRoutineWithZone = Routine(
        id: 'r_other',
        title: 'کار دیگر',
        category: Category.work,
        routineType: RoutineType.timeBased,
        notificationLevel: NotificationLevel.normal,
        isEssential: false,
        energyRule: EnergyRule.none,
        zoneId: 'work_zone',
      );

      final boostedScore = scorer.score(workTask, snapshot);
      final regularMatchScore = scorer.score(normalRoutineWithZone, snapshot);
      final unmatchScore = scorer.score(normalRoutine, snapshot);

      expect(boostedScore, 1.5);
      expect(regularMatchScore, 1.0);
      expect(unmatchScore, 0.0);
    });
  });
}
