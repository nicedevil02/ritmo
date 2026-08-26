import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/rie/context_snapshot.dart';
import 'package:ritmo/core/domain/engines/rie/rie_filters.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/domain/models/daily_behavior.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TestClock implements Clock {
  TestClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const familyRealm = RealmData(
    id: 'family_zone',
    name: 'قلمرو خانواده',
    colorHex: '#10B981',
    icon: '👨‍👩‍👧',
    mode: RealmMode.normal,
    hideOtherRealms: true,
  );

  const workRealm = RealmData(
    id: 'work_zone',
    name: 'قلمرو کار',
    colorHex: '#3B82F6',
    icon: '💼',
    mode: RealmMode.focus,
    hideOtherRealms: true,
  );

  group('Real Realm Separation (F-11)', () {
    test('1. hideOtherRealms strictly filters routines from other realms with critical medical exemption', () {
      const filter = ZoneAndEssentialFilter();

      final workRoutine = Routine(
        id: 'r_work_meeting',
        title: 'جلسه اسکرام',
        category: Category.work,
        routineType: RoutineType.timeBased,
        notificationLevel: NotificationLevel.important,
        isEssential: false,
        energyRule: EnergyRule.none,
        zoneId: 'work_zone',
      );

      final familyRoutine = Routine(
        id: 'r_family_dinner',
        title: 'شام با خانواده',
        category: Category.personal,
        routineType: RoutineType.timeBased,
        notificationLevel: NotificationLevel.important,
        isEssential: false,
        energyRule: EnergyRule.none,
        zoneId: 'family_zone',
      );

      final untaggedRoutine = Routine(
        id: 'r_water',
        title: 'نوشیدن آب',
        category: Category.personal,
        routineType: RoutineType.timeBased,
        notificationLevel: NotificationLevel.important,
        isEssential: false,
        energyRule: EnergyRule.none,
      );

      final criticalMedicalWorkTaggedRoutine = Routine(
        id: 'r_insulin',
        title: 'تزریق انسولین',
        category: Category.medical,
        routineType: RoutineType.timeBased,
        notificationLevel: NotificationLevel.important,
        isEssential: true,
        energyRule: EnergyRule.none,
        zoneId: 'work_zone',
      );

      final snapshot = ContextSnapshot(
        now: DateTime(2026, 8, 26, 19, 0),
        appSettings: const {},
        activeZoneId: 'family_zone',
        activeRealmMode: RealmMode.normal,
        hideOtherRealms: true, // F-11 Active!
        currentEnergy: EnergyLevel.medium,
        isMenstruating: false,
        dailyBehavior: DailyBehavior(behavior: 'NORMAL', context: LifeContext.normal),
        blockedRoutineIdsInZone: const {},
        completedRoutineIdsToday: const {},
        routineSchedulesByRoutineId: const {},
        enteredRoutines: [
          workRoutine,
          familyRoutine,
          untaggedRoutine,
          criticalMedicalWorkTaggedRoutine,
        ],
      );

      final result = filter.filter(snapshot.enteredRoutines, snapshot);

      // r_work_meeting MUST be hidden in family realm!
      expect(result.any((r) => r.id == 'r_work_meeting'), isFalse);

      // r_family_dinner and r_water must be present
      expect(result.any((r) => r.id == 'r_family_dinner'), isTrue);
      expect(result.any((r) => r.id == 'r_water'), isTrue);

      // Critical medicine MUST pass through despite work_zone tag
      expect(result.any((r) => r.id == 'r_insulin'), isTrue);
    });
  });

  group('Zone Budgets (F-12)', () {
    test('2. ZoneBudgetRepository CRUD and persistence in SQLite', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE zones (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              color TEXT NOT NULL,
              icon TEXT NOT NULL,
              mode TEXT NOT NULL DEFAULT 'NORMAL',
              isDefault INTEGER NOT NULL DEFAULT 0,
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL
            );
          ''');

          await db.execute('''
            CREATE TABLE zone_budgets (
              zoneId      TEXT PRIMARY KEY,
              minMinutes  INTEGER,
              maxMinutes  INTEGER,
              period      TEXT NOT NULL DEFAULT 'WEEK',
              updatedAt   INTEGER NOT NULL,
              FOREIGN KEY(zoneId) REFERENCES zones(id) ON DELETE CASCADE
            );
          ''');
        },
      );

      final repo = ZoneBudgetRepository();

      const familyBudget = ZoneBudget(
        zoneId: 'family_zone',
        minMinutes: 900, // 15 hours minimum
        period: 'WEEK',
        updatedAt: 1000,
      );

      const workBudget = ZoneBudget(
        zoneId: 'work_zone',
        maxMinutes: 2700, // 45 hours maximum
        period: 'WEEK',
        updatedAt: 1000,
      );

      // Save
      await repo.saveBudget(familyBudget, executor: db);
      await repo.saveBudget(workBudget, executor: db);

      // Load specific
      final loadedFamily = await repo.loadBudget('family_zone', executor: db);
      expect(loadedFamily, isNotNull);
      expect(loadedFamily!.minMinutes, 900);
      expect(loadedFamily.period, 'WEEK');

      // Load all
      final all = await repo.loadAllBudgets(executor: db);
      expect(all.length, 2);

      // Delete
      await repo.deleteBudget('family_zone', executor: db);
      final reloadedFamily = await repo.loadBudget('family_zone', executor: db);
      expect(reloadedFamily, isNull);

      await db.close();
    });
  });

  group('Zone Profiles & Schedule Multi-Tenancy (F-13)', () {
    test('3. ZoneProfileRepository manages schedule profiles and resolver filters by active profile & isEnabled', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE zone_profiles (
              id        TEXT PRIMARY KEY,
              name      TEXT NOT NULL,
              isActive  INTEGER NOT NULL DEFAULT 0,
              createdAt INTEGER NOT NULL
            );
          ''');
        },
      );

      final profileRepo = ZoneProfileRepository();

      final normalWeek = await profileRepo.createProfile('هفته عادی', isActive: true, executor: db);
      final vacation = await profileRepo.createProfile('تعطیلات', isActive: false, executor: db);

      expect(normalWeek.isActive, isTrue);
      expect(vacation.isActive, isFalse);

      var active = await profileRepo.getActiveProfile(executor: db);
      expect(active?.id, normalWeek.id);

      // Switch to vacation profile
      await profileRepo.setActiveProfile(vacation.id, executor: db);
      active = await profileRepo.getActiveProfile(executor: db);
      expect(active?.id, vacation.id);

      // Test ActiveRealmResolver with profileId and isEnabled
      final clock = TestClock(DateTime(2026, 8, 26, 10, 0)); // Wednesday 10:00
      final resolver = ActiveRealmResolver(clock: clock);

      final normalWorkSchedule = RealmScheduleData(
        id: 's_work_normal',
        zoneId: 'work_zone',
        daysOfWeek: const {1, 2, 3, 4, 5, 6, 7},
        startTime: '09:00',
        endTime: '17:00',
        profileId: normalWeek.id,
        isEnabled: true,
      );

      final vacationFamilySchedule = RealmScheduleData(
        id: 's_family_vacation',
        zoneId: 'family_zone',
        daysOfWeek: const {1, 2, 3, 4, 5, 6, 7},
        startTime: '09:00',
        endTime: '17:00',
        profileId: vacation.id,
        isEnabled: true,
      );

      const disabledSchedule = RealmScheduleData(
        id: 's_disabled',
        zoneId: 'work_zone',
        daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
        startTime: '09:00',
        endTime: '17:00',
        isEnabled: false,
      );

      // Under vacation profile: vacationFamilySchedule activates, normalWorkSchedule is ignored
      final stateVacation = resolver.resolve(
        realms: const [workRealm, familyRealm],
        schedules: [normalWorkSchedule, vacationFamilySchedule, disabledSchedule],
        activeProfileId: vacation.id,
      );

      expect(stateVacation, isA<ScheduledRealmState>());
      expect(stateVacation.realmOrNull?.id, 'family_zone');

      // Under normal profile: normalWorkSchedule activates
      final stateNormal = resolver.resolve(
        realms: const [workRealm, familyRealm],
        schedules: [normalWorkSchedule, vacationFamilySchedule, disabledSchedule],
        activeProfileId: normalWeek.id,
      );

      expect(stateNormal, isA<ScheduledRealmState>());
      expect(stateNormal.realmOrNull?.id, 'work_zone');

      await db.close();
    });
  });
}
