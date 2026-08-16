import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// انتخاب‌گر مقیاس تکرار در ذخیره (RIR - Reps In Reserve)
class RirPicker extends StatelessWidget {
  const RirPicker({
    super.key,
    required this.selectedRir,
    required this.onRirSelected,
  });

  final double? selectedRir;
  final ValueChanged<double?> onRirSelected;

  static const List<Map<String, dynamic>> _rirOptions = [
    {'value': 0.0, 'label': '۰', 'desc': 'ناتوانی کامل (بدون تکرار اضافی)'},
    {'value': 1.0, 'label': '۱', 'desc': '۱ تکرار تا خستگی کامل'},
    {'value': 2.0, 'label': '۲', 'desc': '۲ تکرار در ذخیره (فشار مطلوب)'},
    {'value': 3.0, 'label': '۳', 'desc': '۳ تکرار در ذخیره (متوسط)'},
    {'value': 4.0, 'label': '۴+', 'desc': 'بیش از ۴ تکرار (بسیار سبک)'},
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              MovementStrings.strengthRirLabel,
              style: RitmoTextStyles.label(colors.textPrimary),
            ),
            const SizedBox(width: 4),
            Text('(اختیاری)', style: RitmoTextStyles.caption(colors.textTertiary)),
          ],
        ),
        const SizedBox(height: RitmoSpacing.xs),
        Row(
          children: _rirOptions.map((opt) {
            final val = opt['value'] as double;
            final isSel = selectedRir == val;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ChoiceChip(
                  label: Center(child: Text(toPersianDigits(opt['label']))),
                  selected: isSel,
                  selectedColor: sportsColor.withValues(alpha: 0.2),
                  labelStyle: RitmoTextStyles.label(isSel ? sportsColor : colors.textPrimary),
                  onSelected: (selected) {
                    onRirSelected(selected ? val : null);
                  },
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
