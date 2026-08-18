import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/settings/settings_health_service.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';

class SettingsHealthCard extends StatelessWidget {
  const SettingsHealthCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedBuilder(
      animation: SettingsService.instance.revision,
      builder: (context, _) {
        final issues = SettingsHealthService.instance.inspect();

        if (issues.isEmpty) {
          return const SizedBox.shrink();
        }

        final hasError = issues.any((i) => i.severity == SettingsIssueSeverity.error);
        final borderColor = hasError ? colors.medicalRed : colors.accent;
        final bgColor = (hasError ? colors.medicalRed : colors.accent).withValues(alpha: 0.08);

        return Container(
          key: const ValueKey('settings_health_card'),
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasError ? CupertinoIcons.exclamationmark_triangle_fill : CupertinoIcons.info_circle_fill,
                    color: borderColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${toPersianDigits(issues.length)} مورد نیازمند توجه در تنظیمات',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    key: const ValueKey('health_card_autofix_button'),
                    onPressed: () async {
                      RitmoHaptics.confirm();
                      await SettingsHealthService.instance.fixAll();
                      if (context.mounted) {
                        RitmoToast.show(context, 'تنظیمات با موفقیت اصلاح شدند');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: borderColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'اصلاح خودکار',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final issue in issues) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6, left: 6, right: 2),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: borderColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          issue.descriptionFa,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
