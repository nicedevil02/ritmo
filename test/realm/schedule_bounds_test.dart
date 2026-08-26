import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/realm/schedule_bounds.dart';

void main() {
  group('calculateScheduleBounds Tests (B-05)', () {
    test('Standard daytime schedule bounds (09:00 - 17:00)', () {
      final now = DateTime(2026, 8, 26, 12, 0); // 12:00
      final bounds = calculateScheduleBounds(
        now: now,
        startTime: '09:00',
        endTime: '17:00',
      );

      expect(bounds.startDt, DateTime(2026, 8, 26, 9, 0));
      expect(bounds.endDt, DateTime(2026, 8, 26, 17, 0));
      expect(bounds.endDt.isAfter(now), isTrue);
    });

    test('Cross-midnight schedule at night before midnight (23:00 - 05:00 at 23:30)', () {
      final now = DateTime(2026, 8, 26, 23, 30);
      final bounds = calculateScheduleBounds(
        now: now,
        startTime: '23:00',
        endTime: '05:00',
      );

      expect(bounds.startDt, DateTime(2026, 8, 26, 23, 0));
      expect(bounds.endDt, DateTime(2026, 8, 27, 5, 0)); // Next day 05:00!
      expect(bounds.endDt.isAfter(now), isTrue);
      expect(bounds.endDt.difference(now).inMinutes, 330); // 5.5 hours remaining
    });

    test('Cross-midnight schedule in early morning after midnight (23:00 - 05:00 at 01:00)', () {
      final now = DateTime(2026, 8, 27, 1, 0);
      final bounds = calculateScheduleBounds(
        now: now,
        startTime: '23:00',
        endTime: '05:00',
      );

      expect(bounds.startDt, DateTime(2026, 8, 26, 23, 0)); // Yesterday 23:00!
      expect(bounds.endDt, DateTime(2026, 8, 27, 5, 0)); // Today 05:00
      expect(bounds.endDt.isAfter(now), isTrue);
      expect(bounds.endDt.difference(now).inHours, 4);
    });

    test('Cross-midnight schedule boundary edge at 04:59', () {
      final now = DateTime(2026, 8, 27, 4, 59);
      final bounds = calculateScheduleBounds(
        now: now,
        startTime: '23:00',
        endTime: '05:00',
      );

      expect(bounds.startDt, DateTime(2026, 8, 26, 23, 0));
      expect(bounds.endDt, DateTime(2026, 8, 27, 5, 0));
      expect(bounds.endDt.difference(now).inSeconds, 60);
    });

    test('Full day schedule (00:00 - 23:59)', () {
      final now = DateTime(2026, 8, 26, 14, 15);
      final bounds = calculateScheduleBounds(
        now: now,
        startTime: '00:00',
        endTime: '23:59',
      );

      expect(bounds.startDt, DateTime(2026, 8, 26, 0, 0));
      expect(bounds.endDt, DateTime(2026, 8, 26, 23, 59));
    });
  });
}
