import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';

/// ردیف انتخابی تنظیمات (SettingsChoiceRow)
class SettingsChoiceRow<T> extends StatelessWidget {
  const SettingsChoiceRow({
    super.key,
    required this.title,
    this.explanation,
    required this.selectedValue,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final String? explanation;
  final T selectedValue;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      constraints: const BoxConstraints(
        minHeight: MovementLayout.kFieldMinHeight,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: RitmoTextStyles.body(colors.textPrimary)),
                if (explanation != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    explanation!,
                    style: RitmoTextStyles.caption(colors.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: RitmoSpacing.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: options.entries.map((entry) {
              final isSelected = selectedValue == entry.key;

              return Padding(
                padding: const EdgeInsets.only(left: 4),
                child: ChoiceChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  onSelected: (sel) {
                    if (sel) onChanged(entry.key);
                  },
                  selectedColor: sportsColor.withValues(alpha: 0.2),
                  labelStyle:
                      RitmoTextStyles.caption(
                        isSelected ? sportsColor : colors.textSecondary,
                      ).copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                    side: BorderSide(
                      color: isSelected ? sportsColor : colors.border,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
