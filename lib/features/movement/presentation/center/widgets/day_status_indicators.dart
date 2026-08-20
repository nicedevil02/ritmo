import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

/// انواع وضعیت جلسات روز
enum MovementDayStatus { planned, completed, partial, moved, recovery }

// ثابت‌های میکرو-چیدمان نشانگرها (اندازهٔ بصری، نه فاصله‌بندی)
const double _kGlyphSize = 7.0;
const double _kEmptyHeight = 12.0;
const double _kOverflowPadding = 2.0;

/// نشانگر وضعیت جلسات روز — حداکثر ۳ نشانگر با تمایز شکلی و نمادین (نه فقط رنگ)
class DayStatusIndicators extends StatelessWidget {
  const DayStatusIndicators({super.key, required this.statuses});

  final List<MovementDayStatus> statuses;

  @override
  Widget build(BuildContext context) {
    if (statuses.isEmpty) {
      return const SizedBox(height: _kEmptyHeight);
    }

    final colors = context.colors;
    final sportsColor = context.modules.sports;

    // حداکثر ۳ نشانگر؛ در صورت وجود بیش از ۳ مورد، سومی به «+n» تبدیل می‌شود
    final displayCount = statuses.length > 3 ? 2 : statuses.length;
    final overflowCount = statuses.length > 3 ? (statuses.length - 2) : 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < displayCount; i++) ...[
          if (i > 0) const SizedBox(width: RitmoSpacing.xs),
          _StatusGlyph(status: statuses[i], sportsColor: sportsColor),
        ],
        if (overflowCount > 0) ...[
          const SizedBox(width: RitmoSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: _kOverflowPadding),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: BorderRadius.circular(RitmoRadius.badge),
              border: Border.all(
                color: colors.border,
                width: RitmoElevation.borderWidthDark,
              ),
            ),
            child: Text(
              '+${toPersianDigits(overflowCount)}',
              style: RitmoTextStyles.badge(colors.textSecondary),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({required this.status, required this.sportsColor});

  final MovementDayStatus status;
  final Color sportsColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    switch (status) {
      case MovementDayStatus.planned:
        // دایرهٔ توخالی / رینگ
        return Container(
          width: _kGlyphSize,
          height: _kGlyphSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: sportsColor, width: 1.5),
          ),
        );

      case MovementDayStatus.completed:
        // دایرهٔ پر با تیک
        return Container(
          width: _kGlyphSize,
          height: _kGlyphSize,
          decoration: BoxDecoration(
            color: colors.success,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(Icons.check, size: 5.5, color: colors.onPrimary),
          ),
        );

      case MovementDayStatus.partial:
        // رینگ با نقطهٔ مرکزی — نیمه‌تمام
        return Container(
          width: _kGlyphSize,
          height: _kGlyphSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.warning, width: 1.2),
          ),
          child: Center(
            child: Container(
              width: 3.5,
              height: 3.5,
              decoration: BoxDecoration(
                color: colors.warning,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );

      case MovementDayStatus.moved:
        // آیکون جابه‌جایی
        return Icon(Icons.swap_horiz_rounded, size: 9.0, color: colors.warning);

      case MovementDayStatus.recovery:
        // نماد ریکاوری
        return Icon(Icons.spa_rounded, size: 8.0, color: colors.accent);
    }
  }
}
