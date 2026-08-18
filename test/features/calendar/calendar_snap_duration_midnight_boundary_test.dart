import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/calendar/presentation/logic/timeline_snapping.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-30: Prevent Duration Overflow at Midnight in Snapping', () {
    test('snapDurationMinutes(30, startMinutes: 1430) returns null when < 15 mins remain', () {
      // 1440 - 1430 = 10 mins < 15 min minimum
      final snapped = TimelineSnappingHelper.snapDurationMinutes(30, startMinutes: 1430);
      expect(snapped, isNull, reason: 'Must return null when minimum duration cannot fit before midnight');
    });

    test('snapDurationMinutes(600, startMinutes: 1380) clamps strictly to remaining minutes (60)', () {
      // 1440 - 1380 = 60 mins remaining
      final snapped = TimelineSnappingHelper.snapDurationMinutes(600, startMinutes: 1380);
      expect(snapped, equals(60), reason: 'Must clamp to 60 without crossing midnight');
    });

    test('snapStartMinutes sanitizes large duration and clamps start cleanly', () {
      // Duration > 1440 sanitized to 1440 max
      final snapped = TimelineSnappingHelper.snapStartMinutes(500, durationMinutes: 2000);
      expect(snapped, equals(0), reason: 'When duration is full day, start is clamped to 0');
    });
  });
}
