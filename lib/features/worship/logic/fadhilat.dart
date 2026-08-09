/// Fadhilat (First-time prayer window) logic — Section §9 (H-3)

import 'package:ritmo/features/worship/domain/prayer_log_quality.dart';

const double kFadhilatFraction = 0.20;
const Duration kFadhilatMaxDuration = Duration(minutes: 20);

Duration fadhilatLength(DateTime windowStart, DateTime windowEnd) {
  final full = windowEnd.difference(windowStart);
  if (full.isNegative) return Duration.zero;
  final byFraction = full * kFadhilatFraction;
  return byFraction > kFadhilatMaxDuration ? kFadhilatMaxDuration : byFraction;
}

// enum PrayerQuality is replaced by PrayerLogQuality

PrayerLogQuality qualityAt(DateTime now, DateTime windowStart, DateTime windowEnd) {
  if (now.isBefore(windowStart)) return PrayerLogQuality.onTime;
  final fadhilatEnd = windowStart.add(fadhilatLength(windowStart, windowEnd));
  if (!now.isAfter(fadhilatEnd)) return PrayerLogQuality.onTime;
  if (!now.isAfter(windowEnd)) return PrayerLogQuality.inTime;
  return PrayerLogQuality.qada;
}


