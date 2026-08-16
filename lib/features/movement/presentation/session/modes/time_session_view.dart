import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/timer_display.dart';

/// نمای مد مبتنی بر زمان (Time Mode) با تایمر بزرگ و پیشرفت حلقه‌ای
class TimeSessionView extends StatelessWidget {
  const TimeSessionView({
    super.key,
    required this.elapsedSeconds,
    required this.isPaused,
    this.targetDurationMinutes,
  });

  final int elapsedSeconds;
  final bool isPaused;
  final int? targetDurationMinutes;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final targetSec = (targetDurationMinutes ?? 30) * 60;
    final progress = (elapsedSeconds / targetSec).clamp(0.0, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // نمایش حلقه‌ای پیشرفت با تایمر بزرگ در مرکز
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                backgroundColor: colors.surfaceSunken,
                valueColor: AlwaysStoppedAnimation<Color>(sportsColor),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TimerDisplay(
                  elapsedSeconds: elapsedSeconds,
                  isLarge: true,
                  isPaused: isPaused,
                ),
                if (targetDurationMinutes != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'هدف: ${toPersianDigits(targetDurationMinutes)} دقیقه',
                    style: RitmoTextStyles.caption(colors.textSecondary),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: RitmoSpacing.xxl),

        // درصد پیشرفت متنی
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(RitmoRadius.pill),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            'پیشرفت: ${toPersianDigits((progress * 100).toInt())}٪',
            style: RitmoTextStyles.label(sportsColor),
          ),
        ),
      ],
    );
  }
}
