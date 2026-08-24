import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/time_of_day_minutes.dart';

class RitmoTimeRange extends StatelessWidget {
  const RitmoTimeRange({
    super.key,
    required this.startMinutes,
    this.endMinutes,
    this.style,
  });

  final int startMinutes;
  final int? endMinutes;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final defaultStyle =
        (style ?? TextStyle(color: colors.textPrimary, fontSize: 13)).copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
          fontFamily: 'Vazirmatn',
        );

    final startStr = toPersianDigits(TimeOfDayMinutes.format(startMinutes));

    if (endMinutes == null) {
      return Text(
        '\u2066$startStr\u2069',
        style: defaultStyle,
        textDirection: TextDirection.ltr,
      );
    }

    final isOvernight = endMinutes! >= 1440;
    final endClamped = isOvernight ? endMinutes! % 1440 : endMinutes!;
    final endStr = toPersianDigits(TimeOfDayMinutes.format(endClamped));

    final fullString = '\u2066$startStr – $endStr\u2069';

    if (isOvernight) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fullString,
            style: defaultStyle,
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(width: 3),
          Text(
            '+۱',
            style: defaultStyle.copyWith(
              fontSize: (defaultStyle.fontSize ?? 12) * 0.8,
              color: colors.textTertiary,
            ),
          ),
        ],
      );
    }

    return Text(
      fullString,
      style: defaultStyle,
      textDirection: TextDirection.ltr,
    );
  }
}
