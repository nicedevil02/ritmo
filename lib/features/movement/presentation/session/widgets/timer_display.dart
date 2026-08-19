import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

/// نمایشگر تایمر جلسهٔ زنده با ارقام فارسی و ابعاد ثابت ضد لرزش
class TimerDisplay extends StatelessWidget {
  const TimerDisplay({
    super.key,
    required this.elapsedSeconds,
    this.isLarge = true,
    this.isPaused = false,
  });

  final int elapsedSeconds;
  final bool isLarge;
  final bool isPaused;

  String _formatTime(int sec) {
    final hours = sec ~/ 3600;
    final mins = (sec % 3600) ~/ 60;
    final remainingSec = sec % 60;

    final hoursStr = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
    final minsStr = mins.toString().padLeft(2, '0');
    final secStr = remainingSec.toString().padLeft(2, '0');

    return '$hoursStr$minsStr:$secStr';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final formatted = toPersianDigits(_formatTime(elapsedSeconds));
    final textColor = isPaused ? colors.textSecondary : colors.textPrimary;

    final textStyle = isLarge
        ? RitmoTextStyles.heroNumber(textColor).copyWith(letterSpacing: 2.0)
        : RitmoTextStyles.sectionHeadline(textColor);

    return Semantics(
      liveRegion: true,
      label: 'زمان سپری‌شده: $formatted${isPaused ? '، متوقف‌شده' : ''}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isPaused) ...[
            Icon(
              Icons.pause_circle_outline_rounded,
              size: isLarge ? 28 : 20,
              color: colors.warning,
            ),
            const SizedBox(width: RitmoSpacing.xs),
          ],
          Text(formatted, style: textStyle, textDirection: TextDirection.ltr),
        ],
      ),
    );
  }
}
