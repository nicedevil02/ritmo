import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';

void main() {
  group('Foreground Notification Realm Sync (B-01)', () {
    test('ActiveRealmStateX extension extracts realm and effective mode accurately', () {
      final focusRealm = RealmData(
        id: 'work_focus',
        name: 'قلمرو کار متمرکز',
        colorHex: '#3B82F6',
        icon: '💼',
        mode: RealmMode.focus,
      );

      final silentRealm = RealmData(
        id: 'family_silent',
        name: 'قلمرو خانواده',
        colorHex: '#10B981',
        icon: '👨‍👩‍👧',
        mode: RealmMode.silent,
      );

      // 1. Manual state with FOCUS
      final manualState = ManualRealmState(
        realm: focusRealm,
        expireAt: DateTime.now().add(const Duration(minutes: 50)),
        remaining: const Duration(minutes: 50),
        progress: 0.0,
        explanation: 'دستی',
      );
      expect(manualState.realmOrNull?.id, 'work_focus');
      expect(manualState.effectiveMode, RealmMode.focus);
      expect(realmModeToRaw(manualState.effectiveMode), 'FOCUS');

      // 2. Scheduled state with SILENT
      final scheduledState = ScheduledRealmState(
        realm: silentRealm,
        schedule: const RealmScheduleData(
          id: 's1',
          zoneId: 'family_silent',
          daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
          startTime: '18:00',
          endTime: '22:00',
        ),
        startsAt: DateTime.now().subtract(const Duration(hours: 1)),
        endsAt: DateTime.now().add(const Duration(hours: 3)),
        remaining: const Duration(hours: 3),
        progress: 0.25,
        explanation: 'زمان‌بندی‌شده',
      );
      expect(scheduledState.realmOrNull?.id, 'family_silent');
      expect(scheduledState.effectiveMode, RealmMode.silent);
      expect(realmModeToRaw(scheduledState.effectiveMode), 'SILENT');

      // 3. Free state defaults to normal mode and null realm
      const freeState = FreeRealmState();
      expect(freeState.realmOrNull, isNull);
      expect(freeState.effectiveMode, RealmMode.normal);
      expect(realmModeToRaw(freeState.effectiveMode), 'NORMAL');
    });
  });
}
