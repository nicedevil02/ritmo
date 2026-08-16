import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

/// انتخاب‌گر مقیاس پنج‌گانه (ScaleSelector)
/// شامل ۵ دکمه با ابعاد حداقل ۴۸×۴۸ و برچسب‌های متنی مجزا (عدم استفاده از اسلایدر پیوسته).
class ScaleSelector extends StatelessWidget {
  const ScaleSelector({
    super.key,
    required this.title,
    this.selectedValue,
    required this.onChanged,
    this.labels = const ['خیلی کم', 'کم', 'متوسط', 'خوب', 'عالی'],
    this.semanticsGroup = '',
  });

  final String title;
  final int? selectedValue; // ۱ تا ۵
  final ValueChanged<int> onChanged;
  final List<String> labels;
  final String semanticsGroup;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: RitmoTextStyles.label(colors.textPrimary),
        ),
        const SizedBox(height: RitmoSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (index) {
            final value = index + 1;
            final isSelected = selectedValue == value;
            final labelText = index < labels.length ? labels[index] : '';
            final semanticLabel = '$semanticsGroup $title، $value از ۵، $labelText';

            return Semantics(
              label: semanticLabel,
              selected: isSelected,
              button: true,
              child: InkWell(
                onTap: () => onChanged(value),
                borderRadius: BorderRadius.circular(RitmoRadius.card),
                child: SizedBox(
                  width: 56,
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected ? sportsColor : colors.surfaceSunken,
                          borderRadius: BorderRadius.circular(RitmoRadius.card),
                          border: Border.all(
                            color: isSelected ? sportsColor : colors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: isSelected
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                              : Text(
                                  toPersianDigits(value),
                                  style: RitmoTextStyles.cardTitle(colors.textPrimary),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labelText,
                        style: RitmoTextStyles.caption(
                          isSelected ? sportsColor : colors.textTertiary,
                        ).copyWith(fontSize: 10),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
