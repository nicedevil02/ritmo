import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/worship/domain/prayer_log_quality.dart';
import 'package:ritmo/features/worship/logic/fadhilat.dart';

void main() {
  group('Fadhilat & PrayerLogQuality', () {
    final start = DateTime(2026, 8, 6, 13, 0);
    final end = DateTime(2026, 8, 6, 18, 0);

    test('fadhilatLength clamps max duration to 20 minutes', () {
      final len = fadhilatLength(start, end);
      expect(len.inMinutes, equals(20));
    });

    test('qualityAt correctly classifies timing', () {
      expect(qualityAt(DateTime(2026, 8, 6, 13, 5), start, end), equals(PrayerLogQuality.onTime));
      expect(qualityAt(DateTime(2026, 8, 6, 13, 19), start, end), equals(PrayerLogQuality.onTime));
      expect(qualityAt(DateTime(2026, 8, 6, 13, 25), start, end), equals(PrayerLogQuality.inTime));
      expect(qualityAt(DateTime(2026, 8, 6, 18, 5), start, end), equals(PrayerLogQuality.qada));
    });
  });
}
