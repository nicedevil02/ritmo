import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

class ScaleSelector extends StatelessWidget {
  const ScaleSelector({
    super.key,
    required this.title,
    required this.selectedValue,
    required this.onChanged,
  });

  final String title;
  final int? selectedValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: RitmoTextStyles.cardTitle(colors.textPrimary)),
        const SizedBox(height: RitmoSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (i) {
            final val = i + 1;
            final isSel = selectedValue == val;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.xs),
                child: InkWell(
                  onTap: () => onChanged(val),
                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.sm),
                    decoration: BoxDecoration(
                      color: isSel ? sportsColor : colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(RitmoRadius.card),
                      border: Border.all(
                        color: isSel ? sportsColor : colors.borderSubtle,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      toPersianDigits(val),
                      style: RitmoTextStyles.cardTitle(
                        isSel ? colors.onPrimary : colors.textPrimary,
                      ),
                    ),
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
