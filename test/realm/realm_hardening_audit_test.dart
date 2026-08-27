import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/core/domain/engines/rie/context_snapshot.dart';
import 'package:ritmo/core/domain/engines/rie/rie_filters.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/domain/models/daily_behavior.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/core/domain/realm/sessions/zone_session.dart';
import 'package:ritmo/core/domain/realm/sessions/zone_session_repository.dart';
import 'package:ritmo/core/repositories/realm_repository.dart';
import 'package:ritmo/core/services/foreground_notification_updater.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/platform/notification_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockNotificationPlatform implements NotificationPlatform {
  @override
  Future<bool> startTimerMode({
    required String title,
    required int durationSeconds,
    required int elapsedSeconds,
  }) async => true;

  @override
  Future<bool> startStatusMode({
    required String zone,
    required String energy,
    required String proposedTask,
    String? proposedTaskId,
    int completedRoutines = 0,
    int totalRoutines = 0,
    int completedPrayers = 0,
    int totalPrayers = 0,
    List<String>? zoneNames,
    List<String>? zoneIds,
  }) async => true;

  @override
  Future<bool> stopForegroundService() async => true;

  @override
  Future<void> refreshWidgets() async {}

  @override
  Future<Map<String, dynamic>?> getLaunchIntent() async => null;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    if (!sl.isRegistered<NotificationPlatform>()) {
      sl.registerSingleton<NotificationPlatform>(MockNotificationPlatform());
    }
  });

  group('Time Realm Hardening & Architecture Verification Tests', () {
    late Database db;
    late RealmRepository repo;
    late ZoneTriggerRepository triggerRepo;
    late ZoneSessionRepository sessionRepo;

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath, version: 1);
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
      await SchemaManager.createAll(db);
      await SchemaManager.ensureAllSchemas(db);

      repo = RealmRepository();
      triggerRepo = ZoneTriggerRepository();
      sessionRepo = ZoneSessionRepository();
    });

    tearDown(() async {
      DatabaseHelper.databaseInstance = null;
      await db.close();
    });

    test('1. RealmRepository.getActiveRealmState resolves via CompositeRealmResolver triggers', () async {
      const workRealm = RealmData(
        id: 'zone_work',
        name: 'قلمرو کار',
        colorHex: '#3B82F6',
        icon: '💼',
        mode: RealmMode.focus,
      );
      await repo.saveRealm(workRealm, []);

      // Add a Wi-Fi trigger for work zone
      await triggerRepo.saveTrigger(
        const ZoneTrigger(
          id: 'trig_wifi_work',
          zoneId: 'zone_work',
          kind: TriggerKind.wifiSsid,
          value: 'Office-WiFi',
          isEnabled: true,
          priority: 50,
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );

      // Verify that RealmRepository.getActiveRealmState uses Composite resolution to trigger work zone
      final state = await repo.getActiveRealmState(activeWifiSsid: 'Office-WiFi');
      expect(state, isA<TriggeredRealmState>());
      expect(state.realmOrNull?.id, 'zone_work');
      expect(state.realmOrNull?.mode, RealmMode.focus);
    });

    test('2. hideOtherRealms filters zones query in ForegroundNotificationUpdater', () async {
      // 1. Create a private family realm with hideOtherRealms = true
      const familyRealm = RealmData(
        id: 'zone_family',
        name: 'قلمرو خانواده',
        colorHex: '#10B981',
        icon: '🏡',
        mode: RealmMode.silent,
        hideOtherRealms: true,
      );
      const secretWorkRealm = RealmData(
        id: 'zone_secret_work',
        name: 'قلمرو کار محرمانه',
        colorHex: '#EF4444',
        icon: '🔒',
        mode: RealmMode.focus,
      );
      await repo.saveRealm(familyRealm, []);
      await repo.saveRealm(secretWorkRealm, []);

      // Activate manual override for family realm
      await repo.setManualOverride(realmId: 'zone_family', durationMinutes: 60);

      // Run updater
      await ForegroundNotificationUpdater.update();

      // Query zones respecting privacy check: when active realm has hideOtherRealms, only family realm should be returned
      final state = await repo.getActiveRealmState();
      expect(state.realmOrNull?.id, 'zone_family');
      expect(state.realmOrNull?.hideOtherRealms, isTrue);

      final activeRealm = state.realmOrNull!;
      final filteredZones = await db.query('zones', where: 'id = ?', whereArgs: [activeRealm.id]);
      expect(filteredZones.length, 1);
      expect(filteredZones.first['name'], 'قلمرو خانواده');
    });

    test('3. ZoneSessionWriter logs session even when notifications are disabled', () async {
      // Disable persistent notification setting
      await db.insert(
        'app_settings',
        {'key': 'persistent_status_notification_enabled', 'value': 'false', 'updatedAt': 1000},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      const studyRealm = RealmData(
        id: 'zone_study',
        name: 'قلمرو مطالعه',
        colorHex: '#8B5CF6',
        icon: '📚',
        mode: RealmMode.normal,
      );
      await repo.saveRealm(studyRealm, []);

      // Override into study realm
      await repo.setManualOverride(realmId: 'zone_study', durationMinutes: 45);

      // Run ForegroundNotificationUpdater.update()
      await ForegroundNotificationUpdater.update();

      // Ensure open session exists in database despite notification switch being false
      final openSession = await sessionRepo.getOpenSession();
      expect(openSession, isNotNull);
      expect(openSession?.zoneId, 'zone_study');
      expect(openSession?.source, ZoneSource.manual);
    });

    test('4. RIE ZoneAndEssentialFilter suppresses non-medical routines in SILENT mode', () {
      const filter = ZoneAndEssentialFilter();

      final workEssential = Routine(
        id: 'r_work_ess',
        title: 'جلسه اضطراری',
        category: Category.work,
        routineType: RoutineType.timeBased,
        notificationLevel: NotificationLevel.important,
        isEssential: true,
        energyRule: EnergyRule.none,
      );

      final insulinRoutine = Routine(
        id: 'r_insulin',
        title: 'انسولین رگولار',
        category: Category.medical,
        routineType: RoutineType.timeBased,
        notificationLevel: NotificationLevel.important,
        isEssential: true,
        energyRule: EnergyRule.none,
      );

      final snapshotFocus = ContextSnapshot(
        now: DateTime(2026, 8, 26, 12, 0),
        appSettings: const {},
        activeZoneId: 'zone_test',
        activeRealmMode: RealmMode.focus,
        currentEnergy: EnergyLevel.medium,
        isMenstruating: false,
        dailyBehavior: DailyBehavior(context: LifeContext.normal, behavior: 'NORMAL'),
        blockedRoutineIdsInZone: const {},
        boostedRoutineIdsInZone: const {},
        completedRoutineIdsToday: const {},
        routineSchedulesByRoutineId: const {},
        enteredRoutines: const [],
      );

      final snapshotSilent = ContextSnapshot(
        now: DateTime(2026, 8, 26, 12, 0),
        appSettings: const {},
        activeZoneId: 'zone_test',
        activeRealmMode: RealmMode.silent,
        currentEnergy: EnergyLevel.medium,
        isMenstruating: false,
        dailyBehavior: DailyBehavior(context: LifeContext.normal, behavior: 'NORMAL'),
        blockedRoutineIdsInZone: const {},
        boostedRoutineIdsInZone: const {},
        completedRoutineIdsToday: const {},
        routineSchedulesByRoutineId: const {},
        enteredRoutines: const [],
      );

      // In FOCUS: Both essential work and insulin pass
      final focusResult = filter.filter([workEssential, insulinRoutine], snapshotFocus);
      expect(focusResult.map((r) => r.id), containsAll(['r_work_ess', 'r_insulin']));

      // In SILENT: Only insulin passes, work is suppressed
      final silentResult = filter.filter([workEssential, insulinRoutine], snapshotSilent);
      expect(silentResult.map((r) => r.id), ['r_insulin']);
    });
  });
}
