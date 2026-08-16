import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// بنر فقط برای محیط توسعه و ساخت داخلی — در بیلد نهایی کاربر به صورت const از درخت حذف می‌شود
class DevOnlyBanner extends StatelessWidget {
  const DevOnlyBanner({
    super.key,
    this.text = MovementStrings.devOnlyBannerText,
  });

  final String text;

  static const bool _isInternalBuild =
      bool.fromEnvironment('MOVEMENT_GREENFIELD_INTERNAL', defaultValue: false);

  @override
  Widget build(BuildContext context) {
    if (!_isInternalBuild) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.md,
        vertical: RitmoSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: colors.border,
            width: RitmoElevation.borderWidthDark,
          ),
        ),
      ),
      child: Center(
        child: Text(
          text,
          style: RitmoTextStyles.badge(colors.primary),
        ),
      ),
    );
  }
}
