import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/presentation/widgets/kick_session_tracker.dart';

void main() {
  group('UX-04 KickSessionTracker Tests', () {
    test('groups taps within 2 minutes into single movement burst', () {
      final tracker = KickSessionTracker();
      final t1 = DateTime(2026, 8, 10, 10, 0);
      final t2 = DateTime(2026, 8, 10, 10, 1); // 1 min gap -> same burst
      final t3 = DateTime(2026, 8, 10, 10, 4); // 3 mins gap -> new burst

      tracker.registerTap(t1);
      expect(tracker.count, equals(1));

      tracker.registerTap(t2);
      expect(tracker.count, equals(1)); // Still 1

      tracker.registerTap(t3);
      expect(tracker.count, equals(2)); // Increment to 2
    });

    test('reaches target count of 10 and signals completion', () {
      final tracker = KickSessionTracker();
      var now = DateTime(2026, 8, 10, 10, 0);

      bool isDone = false;
      for (int i = 0; i < 10; i++) {
        now = now.add(const Duration(minutes: 3));
        isDone = tracker.registerTap(now);
      }

      expect(tracker.count, equals(10));
      expect(isDone, isTrue);
    });

    test('detects 2-hour session expiry', () {
      final tracker = KickSessionTracker();
      final start = DateTime(2026, 8, 10, 10, 0);
      tracker.registerTap(start);

      final notExpired = DateTime(2026, 8, 10, 11, 30);
      final expired = DateTime(2026, 8, 10, 12, 1);

      expect(tracker.isExpired(notExpired), isFalse);
      expect(tracker.isExpired(expired), isTrue);
    });

    test('evaluates personal baseline comparison accurately', () {
      expect(
        KickSessionTracker.evaluatePersonalBaseline(
          currentDurationSecs: 3600,
          baselineSecs: 2000,
        ),
        equals('این جلسه طولانی‌تر از الگوی معمول شما بود.'),
      );

      expect(
        KickSessionTracker.evaluatePersonalBaseline(
          currentDurationSecs: 2100,
          baselineSecs: 2000,
        ),
        isNull,
      );

      expect(
        KickSessionTracker.evaluatePersonalBaseline(
          currentDurationSecs: 3000,
          baselineSecs: null,
        ),
        isNull,
      );
    });
  });
}
