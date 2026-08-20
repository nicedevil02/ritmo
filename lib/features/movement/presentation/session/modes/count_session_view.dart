import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/counter_control.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/timer_display.dart';

/// نمای مد مبتنی بر شمارش/تکرار (Count Mode)
class CountSessionView extends StatelessWidget {
  const CountSessionView({
    super.key,
    required this.elapsedSeconds,
    required this.isPaused,
    required this.currentCount,
    required this.targetCount,
    required this.onCountChanged,
    this.currentSet = 1,
    this.totalSets,
  });

  final int elapsedSeconds;
  final bool isPaused;
  final int currentCount;
  final int? targetCount;
  final ValueChanged<int> onCountChanged;
  final int currentSet;
  final int? totalSets;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // تایمر در بالای صفحه
        TimerDisplay(
          elapsedSeconds: elapsedSeconds,
          isLarge: false,
          isPaused: isPaused,
        ),
        const SizedBox(height: RitmoSpacing.lg),

        // کنترل شمارندهٔ مرکزی
        CounterControl(
          currentCount: currentCount,
          targetCount: targetCount,
          onCountChanged: onCountChanged,
          currentSet: currentSet,
          totalSets: totalSets,
        ),
      ],
    );
  }
}
