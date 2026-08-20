// test/supplementary_sports/movement_phase_3_test.dart
//
// تست‌های واحد برای فاز ۳: موتور جلسه زنده
// بررسی صحت رفتارهای زمانی مدل MovementSession.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_session.dart';

void main() {
  group('Phase 3 | MovementSession elapsedMs wall clock tests', () {
    test('elapsedMs calculates correct duration in ACTIVE state without pause', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final session = MovementSession(
        id: 'session_1',
        kindCode: 'RUNNING',
        sessionMode: 'FREE',
        status: MovementSessionStatus.active,
        startedAt: now - 5000, // 5 seconds ago
        pausedMs: 0,
        createdAt: now,
        updatedAt: now,
      );

      final elapsed = session.elapsedMs;
      // Allow slight delta due to execution time
      expect(elapsed, closeTo(5000, 200));
    });

    test('elapsedMs calculates correct duration in completed state', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final session = MovementSession(
        id: 'session_1',
        kindCode: 'RUNNING',
        sessionMode: 'FREE',
        status: MovementSessionStatus.completed,
        startedAt: now - 10000,
        endedAt: now - 2000,
        pausedMs: 1000,
        createdAt: now,
        updatedAt: now,
      );

      // (now - 2000) - (now - 10000) - 1000 = 8000 - 1000 = 7000
      expect(session.elapsedMs, equals(7000));
    });

    test('elapsedMs calculates correct duration in PAUSED state using pauseStartedAt from liveJson', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final pauseStarted = now - 3000;
      final liveJson = jsonEncode({'pauseStartedAt': pauseStarted});

      final session = MovementSession(
        id: 'session_1',
        kindCode: 'RUNNING',
        sessionMode: 'FREE',
        status: MovementSessionStatus.paused,
        startedAt: now - 10000,
        pausedMs: 1000,
        liveJson: liveJson,
        createdAt: now,
        updatedAt: now,
      );

      // elapsed = pauseStartedAt - startedAt - pausedMs
      //         = (now - 3000) - (now - 10000) - 1000
      //         = 7000 - 1000 = 6000
      expect(session.elapsedMs, equals(6000));
    });

    test('fromMap converts database row status to correct enum value', () {
      final row = {
        'id': 'session_abc',
        'kindCode': 'WALKING',
        'sessionMode': 'FREE',
        'status': 'PAUSED',
        'startedAt': 123456789,
        'pausedMs': 500,
        'createdAt': 123456789,
        'updatedAt': 123456789,
      };

      final session = MovementSession.fromMap(row);
      expect(session.status, equals(MovementSessionStatus.paused));
      expect(session.pausedMs, equals(500));
      expect(session.id, equals('session_abc'));
    });

    test('fromMap falls back to abandoned for unknown status codes', () {
      final row = {
        'id': 'session_abc',
        'kindCode': 'WALKING',
        'sessionMode': 'FREE',
        'status': 'SOME_UNKNOWN_STATUS',
        'startedAt': 123456789,
        'pausedMs': 0,
        'createdAt': 123456789,
        'updatedAt': 123456789,
      };

      final session = MovementSession.fromMap(row);
      expect(session.status, equals(MovementSessionStatus.abandoned));
    });
  });
}
