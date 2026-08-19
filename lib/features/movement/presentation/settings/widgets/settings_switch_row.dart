import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';

/// ردیف سوییچ تنظیمات (SettingsSwitchRow)
/// همراه با توضیح یک‌خطی اجباری از اثر واقعی تغییر تنظیم، و ارتفاع حداقل kFieldMinHeight.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.explanation,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String explanation; // توضیح یک‌خطی اثر واقعی
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
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
                  const SizedBox(height: 2),
                  Text(
                    explanation,
                    style: RitmoTextStyles.caption(colors.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: RitmoSpacing.md),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: sportsColor,
            ),
          ],
        ),
      ),
    );
  }
}
