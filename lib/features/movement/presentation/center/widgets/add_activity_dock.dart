import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// داک شناور پایین صفحه برای افزودن سریع فعالیت
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
      container: true,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: MovementLayout.kDockHeight,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: RitmoSpacing.lg,
              vertical: RitmoSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceElevated.withValues(alpha: 0.88),
              border: Border(
                top: BorderSide(
                  color: colors.border,
                  width: RitmoElevation.borderWidthDark,
                ),
              ),
            ),
            child: Center(
              child: AnimatedContainer(
                duration: RitmoMotion.effective(context, RitmoMotion.state),
                width: isCompact ? 56.0 : double.infinity,
                constraints: const BoxConstraints(
                  minHeight: MovementLayout.kPrimaryButtonHeight,
                ),
                child: FilledButton.icon(
                  onPressed: () {
                    RitmoHapticsPolicy.selection();
                    onAddActivity();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: sportsColor,
                    foregroundColor: colors.onPrimary,
                    minimumSize: Size(
                      isCompact ? 56.0 : double.infinity,
                      MovementLayout.kPrimaryButtonHeight,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.pill),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: isCompact
                      ? const SizedBox.shrink()
                      : Text(
                          MovementStrings.centerAddActivity,
                          style: RitmoTextStyles.label(colors.onPrimary).copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
