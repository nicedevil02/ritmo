import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';

class TestClock implements Clock {
  TestClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

void main() {
  group('ActiveRealmResolver Priority & Edge Cases (B-06, B-07, B-12)', () {
    final workRealm = RealmData(
      id: 'work',
      name: 'قلمرو کار',
      colorHex: '#3B82F6',
      icon: '💼',
      mode: RealmMode.focus,
    );

    final familyRealm = RealmData(
      id: 'family',
      name: 'قلمرو خانواده',
      colorHex: '#10B981',
      icon: '👨‍👩‍👧',
      mode: RealmMode.silent,
    );

    final defaultRealm = RealmData(
      id: 'personal',
      name: 'قلمرو شخصی',
      colorHex: '#8B5CF6',
      icon: '🌱',
      mode: RealmMode.normal,
      isDefault: true,
    );

    test('1. Manual override takes top priority and calculates dynamic progress (B-07)', () {
      final now = DateTime(2026, 8, 26, 10, 30); // 10:30
      final startedMs = DateTime(2026, 8, 26, 10, 0).millisecondsSinceEpoch; // started 10:00 (30m ago)
      final untilMs = DateTime(2026, 8, 26, 11, 0).millisecondsSinceEpoch; // ends 11:00 (30m left, total 60m)

      final resolver = ActiveRealmResolver(clock: TestClock(now));
      final state = resolver.resolve(
        realms: [workRealm, familyRealm],
        schedules: [
          RealmScheduleData(
            id: 's_work',
            zoneId: 'work',
            daysOfWeek: {now.weekday},
            startTime: '09:00',
            endTime: '17:00',
          ),
        ],
        overrideRealmId: 'family',
        overrideUntilMs: untilMs,
        overrideStartedMs: startedMs,
      );

      expect(state, isA<ManualRealmState>());
      final manual = state as ManualRealmState;
      expect(manual.realm.id, 'family');
      expect(manual.remaining.inMinutes, 30);
      expect(manual.progress, closeTo(0.5, 0.01)); // 30m / 60m = 0.5 progress!
    });

    test('2. Next schedule candidates are sorted by start timestamp ascending (B-06)', () {
      // Current time is 08:00
      final now = DateTime(2026, 8, 26, 8, 0);

      // Schedules inserted in reverse order: 20:00, 14:00, 09:00
      final schedules = [
        RealmScheduleData(
          id: 's_night',
          zoneId: 'family',
          daysOfWeek: {now.weekday},
          startTime: '20:00',
          endTime: '22:00',
        ),
        RealmScheduleData(
          id: 's_afternoon',
          zoneId: 'personal',
          daysOfWeek: {now.weekday},
          startTime: '14:00',
          endTime: '16:00',
        ),
        RealmScheduleData(
          id: 's_morning',
          zoneId: 'work',
          daysOfWeek: {now.weekday},
          startTime: '09:00',
          endTime: '12:00',
        ),
      ];

      final overrideUntilMs = DateTime(2026, 8, 26, 8, 30).millisecondsSinceEpoch;
      final resolver = ActiveRealmResolver(clock: TestClock(now));

      final state = resolver.resolve(
        realms: [workRealm, familyRealm, defaultRealm],
        schedules: schedules,
        overrideRealmId: 'personal',
        overrideUntilMs: overrideUntilMs,
        overrideStartedMs: now.millisecondsSinceEpoch,
      );

      expect(state, isA<ManualRealmState>());
      final manual = state as ManualRealmState;
      // Nearest upcoming schedule must be 09:00 (work), NOT 20:00 or 14:00!
      expect(manual.nextRealmName, 'قلمرو کار');
      expect(manual.nextRealmTimeStr, '09:00');
    });

    test('3. Default realm activates when outside all scheduled windows (B-12)', () {
      final now = DateTime(2026, 8, 26, 13, 0); // 13:00 (outside 09:00-12:00 and 18:00-22:00)

      final schedules = [
        RealmScheduleData(
          id: 's_work',
          zoneId: 'work',
          daysOfWeek: {now.weekday},
          startTime: '09:00',
          endTime: '12:00',
        ),
        RealmScheduleData(
          id: 's_family',
          zoneId: 'family',
          daysOfWeek: {now.weekday},
          startTime: '18:00',
          endTime: '22:00',
        ),
      ];

      final resolver = ActiveRealmResolver(clock: TestClock(now));
      final state = resolver.resolve(
        realms: [workRealm, familyRealm, defaultRealm],
        schedules: schedules,
      );

      expect(state, isA<ScheduledRealmState>());
      final scheduled = state as ScheduledRealmState;
      expect(scheduled.realm.id, 'personal');
      expect(scheduled.isDefaultFallback, isTrue);
      expect(scheduled.explanation, contains('قلمرو پیش‌فرض'));
    });

    test('4. FreeRealmState returns when outside schedules and no default realm exists', () {
      final now = DateTime(2026, 8, 26, 13, 0);
      final nonDefaultRealms = [workRealm, familyRealm]; // Neither is default

      final resolver = ActiveRealmResolver(clock: TestClock(now));
      final state = resolver.resolve(
        realms: nonDefaultRealms,
        schedules: [
          RealmScheduleData(
            id: 's_work',
            zoneId: 'work',
            daysOfWeek: {now.weekday},
            startTime: '09:00',
            endTime: '12:00',
          ),
        ],
      );

      expect(state, isA<FreeRealmState>());
      expect(state.isFree, isTrue);
    });

    test('5. Shorter duration schedule wins during schedule overlaps (ق-۹)', () {
      final now = DateTime(2026, 8, 26, 10, 0); // 10:00

      // Schedule 1: Full day 09:00 - 17:00 (8h = 480 min)
      // Schedule 2: Deep focus 10:00 - 11:30 (1.5h = 90 min)
      final schedules = [
        RealmScheduleData(
          id: 's_broad',
          zoneId: 'personal',
          daysOfWeek: {now.weekday},
          startTime: '09:00',
          endTime: '17:00',
        ),
        RealmScheduleData(
          id: 's_narrow',
          zoneId: 'work',
          daysOfWeek: {now.weekday},
          startTime: '10:00',
          endTime: '11:30',
        ),
      ];

      final resolver = ActiveRealmResolver(clock: TestClock(now));
      final state = resolver.resolve(
        realms: [workRealm, defaultRealm],
        schedules: schedules,
      );

      expect(state, isA<ScheduledRealmState>());
      final scheduled = state as ScheduledRealmState;
      expect(scheduled.realm.id, 'work');
      expect(scheduled.schedule.id, 's_narrow');
    });
  });
}
