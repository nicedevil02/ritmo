import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('MvSession Session Metrics Unit Tests (S4-T2)', () {
    test('Mountain Hiking session round-trip serialization and computed metrics', () {
      const startedAt = 1700000000;
      const endedAt = startedAt + (180 * 60 * 1000); // 180 minutes elapsed = 10800000 ms

      const hikingSession = MvSession(
        id: 'sess_hike_tochal',
        kindCode: 'HIKING',
        sessionMode: MvSessionMode.route,
        status: MvSessionStatus.completed,
        startedAt: startedAt,
        endedAt: endedAt,
        pausedMs: 0,
        overallFeeling: 5,
        note: 'صعود موفق به قله توچال',
        distanceM: 9400.0,
        elevationGainM: 780.0,
        laps: 0,
        packWeightKg: 6.0,
        rpe1To10: 7,
        effortSource: 'user',
        routeId: 42,
        createdAt: startedAt,
        updatedAt: endedAt,
      );

      // 1. Check computed getters
      expect(hikingSession.elapsedMinutes, equals(180));
      // sessionLoad = rpe * elapsedMinutes = 7 * 180 = 1260
      expect(hikingSession.sessionLoad, equals(1260));

      // paceSecPerKm = (elapsedMs / 1000) / (distanceM / 1000) = (10800) / (9.4) ~ 1148.936 sec/km (~19:08 min/km)
      expect(hikingSession.paceSecPerKm, isNotNull);
      expect(hikingSession.paceSecPerKm, closeTo(1148.936, 0.01));

      // 2. Serialization roundtrip
      final map = hikingSession.toMap();
      expect(map['distanceM'], equals(9400.0));
      expect(map['elevationGainM'], equals(780.0));
      expect(map['laps'], equals(0));
      expect(map['packWeightKg'], equals(6.0));
      expect(map['rpe1To10'], equals(7));
      expect(map['effortSource'], equals('user'));
      expect(map['routeId'], equals(42));

      final restored = MvSession.fromMap(map);
      expect(restored.id, equals(hikingSession.id));
      expect(restored.kindCode, equals('HIKING'));
      expect(restored.distanceM, equals(9400.0));
      expect(restored.elevationGainM, equals(780.0));
      expect(restored.laps, equals(0));
      expect(restored.packWeightKg, equals(6.0));
      expect(restored.rpe1To10, equals(7));
      expect(restored.effortSource, equals('user'));
      expect(restored.routeId, equals(42));
      expect(restored.sessionLoad, equals(1260));
      expect(restored.paceSecPerKm, closeTo(1148.936, 0.01));

      // 3. copyWith functionality
      final updated = hikingSession.copyWith(
        distanceM: 10000.0,
        rpe1To10: 8,
      );
      expect(updated.distanceM, equals(10000.0));
      expect(updated.rpe1To10, equals(8));
      expect(updated.elevationGainM, equals(780.0));
      expect(updated.sessionLoad, equals(8 * 180));
    });

    test('Null safety for sessionLoad and paceSecPerKm when metrics are missing or 0', () {
      const basicSession = MvSession(
        id: 'sess_basic',
        kindCode: 'BODYWEIGHT',
        startedAt: 1700000000,
        endedAt: 1700000000 + (30 * 60 * 1000),
        createdAt: 1700000000,
        updatedAt: 1700000000,
      );

      expect(basicSession.sessionLoad, isNull);
      expect(basicSession.paceSecPerKm, isNull);
    });
  });
}
