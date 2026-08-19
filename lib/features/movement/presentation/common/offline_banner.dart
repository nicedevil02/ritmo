import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// بنر باریک و غیرمسدودکننده برای اعلام وضعیت آفلاین در بخش‌های نیازمند شبکه
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.message = MovementStrings.offlineBannerText,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.14),
        border: Border(
          bottom: BorderSide(
            color: colors.warning.withValues(alpha: 0.3),
            width: RitmoElevation.borderWidthDark,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 14.0, color: colors.warning),
          const SizedBox(width: RitmoSpacing.xs),
          Text(message, style: RitmoTextStyles.badge(colors.warning)),
        ],
      ),
    );
  }
}
