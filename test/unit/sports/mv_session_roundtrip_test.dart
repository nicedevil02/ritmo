import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('MvSession Roundtrip & Fields Completeness Tests (S0-T1)', () {
    test('roundtrip preserves overallFeeling and note losslessly', () {
      const session = MvSession(
        id: 'test_session_1',
        kindCode: 'BODYWEIGHT',
        startedAt: 1000000,
        endedAt: 1003600,
        pausedMs: 600,
        overallFeeling: 4,
        note: 'زانو کمی درد گرفت',
        createdAt: 1000000,
        updatedAt: 1003600,
      );

      final map = session.toMap();
      expect(map['overallFeeling'], equals(4));
      expect(map['note'], equals('زانو کمی درد گرفت'));

      final restored = MvSession.fromMap(map);
      expect(restored.id, equals('test_session_1'));
      expect(restored.kindCode, equals('BODYWEIGHT'));
      expect(restored.overallFeeling, equals(4));
      expect(restored.note, equals('زانو کمی درد گرفت'));
      expect(restored.startedAt, equals(1000000));
      expect(restored.endedAt, equals(1003600));
      expect(restored.pausedMs, equals(600));
    });

    test(
      'toMap contains every declared field of MvSession with zero omissions',
      () {
        const session = MvSession(
          id: 'session_exhaustive',
          kindCode: 'FOOTBALL',
          routineId: 'routine_1',
          occurrenceId: 'occ_1',
          prescriptionId: 'presc_1',
          sessionMode: MvSessionMode.match,
          status: MvSessionStatus.completed,
          startedAt: 100,
          endedAt: 200,
          pausedMs: 10,
          targetJson: '{"target": 1}',
          liveJson: '{"live": 1}',
          workoutLogId: 'log_1',
          overallFeeling: 5,
          note: 'عالی بود',
          createdAt: 100,
          updatedAt: 200,
        );

        final map = session.toMap();

        final expectedKeys = <String>{
          'id',
          'kindCode',
          'routineId',
          'occurrenceId',
          'prescriptionId',
          'sessionMode',
          'status',
          'startedAt',
          'endedAt',
          'pausedMs',
          'targetJson',
          'liveJson',
          'workoutLogId',
          'overallFeeling',
          'note',
          'createdAt',
          'updatedAt',
        };

        expect(
          map.keys.toSet(),
          equals(expectedKeys),
          reason: 'toMap must include exactly all declared fields of MvSession',
        );

        final roundtrip = MvSession.fromMap(map);
        expect(roundtrip.id, equals(session.id));
        expect(roundtrip.kindCode, equals(session.kindCode));
        expect(roundtrip.routineId, equals(session.routineId));
        expect(roundtrip.occurrenceId, equals(session.occurrenceId));
        expect(roundtrip.prescriptionId, equals(session.prescriptionId));
        expect(roundtrip.sessionMode, equals(session.sessionMode));
        expect(roundtrip.status, equals(session.status));
        expect(roundtrip.startedAt, equals(session.startedAt));
        expect(roundtrip.endedAt, equals(session.endedAt));
        expect(roundtrip.pausedMs, equals(session.pausedMs));
        expect(roundtrip.targetJson, equals(session.targetJson));
        expect(roundtrip.liveJson, equals(session.liveJson));
        expect(roundtrip.workoutLogId, equals(session.workoutLogId));
        expect(roundtrip.overallFeeling, equals(session.overallFeeling));
        expect(roundtrip.note, equals(session.note));
        expect(roundtrip.createdAt, equals(session.createdAt));
        expect(roundtrip.updatedAt, equals(session.updatedAt));
      },
    );
  });
}
