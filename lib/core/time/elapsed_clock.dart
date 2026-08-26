import 'package:flutter/foundation.dart';

/// Background-resilient wall-clock timer that avoids throttling and drift (P-C).
class ElapsedClock {
  final DateTime startedAt;
  final Duration pausedAccumulated;
  final DateTime? pausedAt;

  const ElapsedClock({
    required this.startedAt,
    this.pausedAccumulated = Duration.zero,
    this.pausedAt,
  });

  bool get isPaused => pausedAt != null;

  /// Calculates real elapsed time against wall clock at [now].
  Duration elapsedAt(DateTime now) {
    if (isPaused && pausedAt != null) {
      return pausedAt!.difference(startedAt) - pausedAccumulated;
    }
    return now.difference(startedAt) - pausedAccumulated;
  }

  /// Calculates real elapsed duration from wall clock right now.
  Duration get elapsed => elapsedAt(DateTime.now());

  /// Returns total elapsed seconds, clamped at non-negative value.
  int get elapsedSeconds => elapsed.inSeconds.clamp(0, 86400 * 365);
}

/// Adaptive ticker providing notifications at dynamic intervals (1s below 60s, 30s/60s above).
class AdaptiveTicker extends ValueNotifier<DateTime> {
  AdaptiveTicker([DateTime? initial]) : super(initial ?? DateTime.now());

  void tick() {
    value = DateTime.now();
  }
}
