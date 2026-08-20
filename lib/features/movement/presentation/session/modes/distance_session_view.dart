import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/distance_input.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/timer_display.dart';

/// نمای مد مبتنی بر مسافت (Distance Mode)
class DistanceSessionView extends StatelessWidget {
  const DistanceSessionView({
    super.key,
    required this.distanceKm,
    required this.elapsedSeconds,
    required this.isPaused,
    required this.onDistanceChanged,
    this.targetDistanceKm,
  });

  final double distanceKm;
  final int elapsedSeconds;
  final bool isPaused;
  final ValueChanged<double> onDistanceChanged;
  final double? targetDistanceKm;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // تایمر کوچک
        TimerDisplay(
          elapsedSeconds: elapsedSeconds,
          isLarge: false,
          isPaused: isPaused,
        ),
        const SizedBox(height: RitmoSpacing.xl),

        // کنترل ورود مسافت و نمایش Pace
        DistanceInput(
          distanceKm: distanceKm,
          elapsedSeconds: elapsedSeconds,
          onDistanceChanged: onDistanceChanged,
          targetDistanceKm: targetDistanceKm,
        ),
      ],
    );
  }
}
