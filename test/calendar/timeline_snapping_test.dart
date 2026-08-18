import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/calendar/presentation/logic/timeline_snapping.dart';

void main() {
  group('CAL-55: Timeline Snapping Tests', () {
    test('1. snapStartMinutes snaps to nearest 15 mins, clamps within [0, 1440 - duration], and handles negative inputs', () {
      // Snap to 15
      expect(TimelineSnappingHelper.snapStartMinutes(13), equals(15));
      expect(TimelineSnappingHelper.snapStartMinutes(7), equals(0));
      expect(TimelineSnappingHelper.snapStartMinutes(23), equals(30));

      // Clamp to 1440 - duration (e.g. duration = 60 -> max start is 1380)
      expect(TimelineSnappingHelper.snapStartMinutes(1400, durationMinutes: 60), equals(1380));
      expect(TimelineSnappingHelper.snapStartMinutes(1435, durationMinutes: 30), equals(1410));

      // Negative values clamped to 0
      expect(TimelineSnappingHelper.snapStartMinutes(-20), equals(0));
      expect(TimelineSnappingHelper.snapStartMinutes(-100), equals(0));
    });

    test('2. snapDurationMinutes returns null when less than min duration remains before midnight', () {
      // 1440 - 1430 = 10 minutes < minDurationMinutes (15) -> returns null
      final result = TimelineSnappingHelper.snapDurationMinutes(30, startMinutes: 1430);
      expect(result, isNull);
    });

    test('3. snapDurationMinutes(600, startMinutes: 1380) clamps to 60 mins remaining until midnight', () {
      // 1440 - 1380 = 60 minutes available
      final result = TimelineSnappingHelper.snapDurationMinutes(600, startMinutes: 1380);
      expect(result, equals(60));
    });

    test('4. intervalMinutes: 0 safely falls back to default interval (15) without error', () {
      final snappedStart = TimelineSnappingHelper.snapStartMinutes(23, intervalMinutes: 0);
      expect(snappedStart, equals(30));

      final snappedDur = TimelineSnappingHelper.snapDurationMinutes(40, intervalMinutes: 0);
      expect(snappedDur, equals(45));
    });
  });
}
