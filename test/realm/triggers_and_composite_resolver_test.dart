import 'package:flutter_test/flutter_test.dart';
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

  const workRealm = RealmData(
    id: 'work_zone',
    name: 'قلمرو کار',
    colorHex: '#3B82F6',
    icon: '💼',
    mode: RealmMode.focus,
  );

  const familyRealm = RealmData(
    id: 'family_zone',
    name: 'قلمرو خانواده',
    colorHex: '#10B981',
    icon: '👨‍👩‍👧',
    mode: RealmMode.silent,
  );

  const sleepRealm = RealmData(
    id: 'sleep_zone',
    name: 'قلمرو خواب',
    colorHex: '#6366F1',
    icon: '😴',
    mode: RealmMode.silent,
  );

  const defaultRealm = RealmData(
    id: 'default_zone',
    name: 'قلمرو پیش‌فرض',
    colorHex: '#8B5CF6',
    icon: '🌱',
    mode: RealmMode.normal,
    isDefault: true,
  );

  const workSchedule = RealmScheduleData(
    id: 's_work',
    zoneId: 'work_zone',
    daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
    startTime: '09:00',
    endTime: '17:00',
  );

  group('Priority Engine & Automation Triggers (F-08, F-09, F-10)', () {
    test('1. Wi-Fi trigger activates realm over lower-priority schedule', () async {
      final clock = TestClock(DateTime(2026, 8, 26, 14, 0)); // 14:00 (during workSchedule 09:00-17:00)
      final resolver = ActiveRealmResolver(clock: clock);

      const wifiTrigger = ZoneTrigger(
        id: 'trig_wifi_family',
        zoneId: 'family_zone',
        kind: TriggerKind.wifiSsid,
        value: 'Home_Sweet_Home_5G',
        createdAt: 1000,
        updatedAt: 1000,
      );

      // When connected to Home Wi-Fi, Priority 2 (WiFi Trigger) beats Priority 4 (Work Schedule)
      final state = resolver.resolve(
        realms: [workRealm, familyRealm, defaultRealm],
        schedules: [workSchedule],
        triggers: [wifiTrigger],
        activeWifiSsid: 'Home_Sweet_Home_5G',
      );

      expect(state, isA<TriggeredRealmState>());
      final triggered = state as TriggeredRealmState;
      expect(triggered.realm.id, 'family_zone');
      expect(triggered.explanation, contains('Home_Sweet_Home_5G'));
    });

    test('2. Manual Override beats Wi-Fi Trigger (Priority 1 > Priority 2)', () async {
      final now = DateTime(2026, 8, 26, 14, 0);
      final clock = TestClock(now);
      final resolver = ActiveRealmResolver(clock: clock);

      const wifiTrigger = ZoneTrigger(
        id: 'trig_wifi_family',
        zoneId: 'family_zone',
        kind: TriggerKind.wifiSsid,
        value: 'Home_Sweet_Home_5G',
        createdAt: 1000,
        updatedAt: 1000,
      );

      // Manual override to work_zone
      final state = resolver.resolve(
        realms: [workRealm, familyRealm, defaultRealm],
        schedules: [workSchedule],
        triggers: [wifiTrigger],
        overrideRealmId: 'work_zone',
        overrideUntilMs: now.add(const Duration(minutes: 60)).millisecondsSinceEpoch,
        activeWifiSsid: 'Home_Sweet_Home_5G',
      );

      expect(state, isA<ManualRealmState>());
      final manual = state as ManualRealmState;
      expect(manual.realm.id, 'work_zone');
    });

    test('3. Charger Trigger activates Sleep realm during night window (F-10)', () async {
      final nightTime = DateTime(2026, 8, 26, 23, 30); // 23:30
      final clock = TestClock(nightTime);
      final resolver = ActiveRealmResolver(clock: clock);

      const chargerTrigger = ZoneTrigger(
        id: 'trig_charger_sleep',
        zoneId: 'sleep_zone',
        kind: TriggerKind.charger,
        value: '23:00-06:30',
        createdAt: 1000,
        updatedAt: 1000,
      );

      final state = resolver.resolve(
        realms: [workRealm, familyRealm, sleepRealm, defaultRealm],
        schedules: [workSchedule],
        triggers: [chargerTrigger],
        isCharging: true,
      );

      expect(state, isA<TriggeredRealmState>());
      final triggered = state as TriggeredRealmState;
      expect(triggered.realm.id, 'sleep_zone');
      expect(triggered.explanation, contains('شارژر'));
    });

    test('4. Calendar Tag Trigger activates Study realm (Priority 3)', () async {
      final time = DateTime(2026, 8, 26, 20, 0); // 20:00 (outside work schedule)
      final clock = TestClock(time);
      final resolver = ActiveRealmResolver(clock: clock);

      const calendarTrigger = ZoneTrigger(
        id: 'trig_cal_work',
        zoneId: 'work_zone',
        kind: TriggerKind.calendarTag,
        value: 'meeting',
        createdAt: 1000,
        updatedAt: 1000,
      );

      final state = resolver.resolve(
        realms: [workRealm, familyRealm, defaultRealm],
        schedules: [workSchedule],
        triggers: [calendarTrigger],
        activeCalendarTags: ['Client Meeting', 'Project Alpha'],
      );

      expect(state, isA<TriggeredRealmState>());
      final triggered = state as TriggeredRealmState;
      expect(triggered.realm.id, 'work_zone');
      expect(triggered.explanation, contains('meeting'));
    });

    test('5. CompositeRealmResolver layer architecture resolves all priorities', () async {
      const composite = CompositeRealmResolver();
      final now = DateTime(2026, 8, 26, 11, 0);

      final context = RealmContext(
        now: now,
        realms: const [workRealm, familyRealm, defaultRealm],
        schedules: const [workSchedule],
        triggers: const [],
      );

      final state = composite.resolve(context);
      expect(state, isA<ScheduledRealmState>());
      expect(state.realmOrNull?.id, 'work_zone');
    });

    test('6. ZoneTriggerRepository CRUD operations in SQLite', () async {
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
            CREATE TABLE zone_triggers (
              id TEXT PRIMARY KEY,
              zoneId TEXT NOT NULL,
              kind TEXT NOT NULL,
              value TEXT NOT NULL,
              priority INTEGER NOT NULL DEFAULT 0,
              isEnabled INTEGER NOT NULL DEFAULT 1,
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL,
              FOREIGN KEY(zoneId) REFERENCES zones(id) ON DELETE CASCADE
            );
          ''');
        },
      );

      final repo = ZoneTriggerRepository();
      const trigger = ZoneTrigger(
        id: 'trig_office_wifi',
        zoneId: 'work_zone',
        kind: TriggerKind.wifiSsid,
        value: 'Office_5G',
        priority: 10,
        isEnabled: true,
        createdAt: 1000,
        updatedAt: 1000,
      );

      // 1. Save
      await repo.saveTrigger(trigger, executor: db);

      // 2. Load
      var loaded = await repo.loadTriggers(zoneId: 'work_zone', executor: db);
      expect(loaded.length, 1);
      expect(loaded.first.value, 'Office_5G');
      expect(loaded.first.kind, TriggerKind.wifiSsid);

      // 3. Toggle
      await repo.toggleTrigger('trig_office_wifi', false, executor: db);
      loaded = await repo.loadTriggers(onlyEnabled: true, executor: db);
      expect(loaded.isEmpty, true);

      // 4. Delete
      await repo.deleteTrigger('trig_office_wifi', executor: db);
      loaded = await repo.loadTriggers(executor: db);
      expect(loaded.isEmpty, true);

      await db.close();
    });
  });
}
