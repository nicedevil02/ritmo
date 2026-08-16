import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// داک ثابت پایین صفحه برای افزودن سریع فعالیت.
/// سطح توپ با لبهٔ بالایی و یک لایه سایه از توکن مرکزی — بدون Blur/Glass
/// (شیشه طبق قرارداد فقط برای Bottom Sheet و Overlay جلسه مجاز است).
class AddActivityDock extends StatelessWidget {
  const AddActivityDock({
    super.key,
    required this.onAddActivity,
    this.isCompact = false,
  });

  final VoidCallback onAddActivity;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Semantics(
      button: true,
      label: MovementStrings.centerAddActivity,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: MovementLayout.kDockHeight,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.lg,
          vertical: RitmoSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          border: Border(
            top: BorderSide(
              color: colors.border,
              width: RitmoElevation.borderWidthDark,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Center(
          child: SizedBox(
            width: isCompact ? null : double.infinity,
            height: MovementLayout.kPrimaryButtonHeight,
            child: FilledButton.icon(
              onPressed: () {
                RitmoHapticsPolicy.selection();
                onAddActivity();
              },
              style: FilledButton.styleFrom(
                backgroundColor: sportsColor,
                foregroundColor: colors.onPrimary,
                minimumSize: const Size(
                  MovementLayout.kMinTouchTarget,
                  MovementLayout.kPrimaryButtonHeight,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RitmoRadius.pill),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              // در حالت فشرده هم هرگز متن کاملاً حذف نمی‌شود — فقط کوتاه‌تر می‌شود
              label: Text(
                isCompact
                    ? MovementStrings.dockCompactLabel
                    : MovementStrings.centerAddActivity,
                style: RitmoTextStyles.label(colors.onPrimary).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
