import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/lap_button.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/timer_display.dart';

/// نمای مد مبتنی بر دور/تکرار دوره‌ای (Lap Mode)
class LapSessionView extends StatelessWidget {
  const LapSessionView({
    super.key,
    required this.elapsedSeconds,
    required this.isPaused,
    required this.laps,
    required this.onLapRecorded,
    required this.onUndoLap,
  });

  final int elapsedSeconds;
  final bool isPaused;
  final List<SessionLapItem> laps;
  final ValueChanged<SessionLapItem> onLapRecorded;
  final VoidCallback onUndoLap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // تایمر در بالای صفحه
        TimerDisplay(
          elapsedSeconds: elapsedSeconds,
          isLarge: true,
          isPaused: isPaused,
        ),
        const SizedBox(height: RitmoSpacing.xl),

        // دکمه و آمار دورها
        LapButton(
          laps: laps,
          onLapRecorded: onLapRecorded,
          onUndoLap: onUndoLap,
          currentElapsedSec: elapsedSeconds,
        ),
      ],
    );
  }
}
