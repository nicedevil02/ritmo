import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_event.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';

void main() {
  group('SPORTS-01: Session Sync Unit Test', () {
    test('Finishing supplementary sports session constructs valid MovementEvent', () {
      final startedAt = 1700000000000;
      final finishedAt = 1700002700000; // 45 minutes = 2700 seconds
      final durationSec = ((finishedAt - startedAt) / 1000).round();
      final durationMins = (durationSec / 60).ceil().clamp(1, 300);

      expect(durationMins, equals(45));

      final event = MovementEvent(
        id: 'ss_mvt_session_123',
        kindCode: 'STRENGTH_TRAINING',
        sourceModule: 'sports',
        sourceEntityId: 'session_123',
        loggedAt: startedAt,
        durationMinutes: durationMins,
        intensity: MovementIntensity.high,
        note: 'تمرین بدنسازی با ۵ حرکت',
      );

      expect(event.sourceModule, equals('sports'));
      expect(event.kindCode, equals('STRENGTH_TRAINING'));
      expect(event.durationMinutes, equals(45));
      expect(event.intensity, equals(MovementIntensity.high));
    });
  });
}
