import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// دیالوگ تایید عملیات‌های غیرقابل‌بازگشت یا دارای اثرات گسترده با نمایش شفاف impactList
class MovementConfirmDialog extends StatelessWidget {
  const MovementConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.impactList,
    this.confirmLabel = MovementStrings.commonConfirm,
    this.cancelLabel = MovementStrings.commonCancel,
    this.destructive = false,
  });

  final String title;
  final String message;
  final List<String>? impactList;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Dialog(
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        side: BorderSide(
          color: colors.border,
          width: RitmoElevation.borderWidthDark,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(RitmoSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // عنوان دیالوگ
            Text(
              title,
              style: RitmoTextStyles.cardTitle(
                destructive ? colors.error : colors.textPrimary,
              ),
            ),

            const SizedBox(height: RitmoSpacing.md),

            // پیام اصلی
            Text(message, style: RitmoTextStyles.body(colors.textSecondary)),

            // فهرست پیامدهای قطعی (impactList)
            if (impactList != null && impactList!.isNotEmpty) ...[
              const SizedBox(height: RitmoSpacing.md),
              Container(
                padding: const EdgeInsets.all(RitmoSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceSunken,
                  borderRadius: BorderRadius.circular(RitmoRadius.field),
                  border: Border.all(
                    color: colors.border,
                    width: RitmoElevation.borderWidthDark,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final impact in impactList!) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: RitmoTextStyles.body(
                                destructive ? colors.error : colors.textPrimary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                impact,
                                style: RitmoTextStyles.caption(
                                  colors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: RitmoSpacing.xl),

            // دکمه‌های اکشن
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // دکمهٔ انصراف
                OutlinedButton(
                  onPressed: () {
                    RitmoHapticsPolicy.tap();
                    Navigator.of(context).pop(false);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(
                      color: colors.border,
                      width: RitmoElevation.borderWidthDark,
                    ),
                    minimumSize: const Size(
                      80,
                      MovementLayout.kSecondaryButtonHeight,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                  ),
                  child: Text(
                    cancelLabel,
                    style: RitmoTextStyles.label(colors.textPrimary),
                  ),
                ),

                const SizedBox(width: RitmoSpacing.sm),

                // دکمهٔ تأیید / حذف
                FilledButton(
                  onPressed: () {
                    if (destructive) {
                      RitmoHapticsPolicy.warning();
                    } else {
                      RitmoHapticsPolicy.tap();
                    }
                    Navigator.of(context).pop(true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: destructive
                        ? colors.error
                        : colors.primary,
                    foregroundColor: colors.onPrimary,
                    minimumSize: const Size(
                      80,
                      MovementLayout.kSecondaryButtonHeight,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                  ),
                  child: Text(
                    confirmLabel,
                    style: RitmoTextStyles.label(colors.onPrimary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// تابع کمکی برای نمایش MovementConfirmDialog
Future<bool> showMovementConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  List<String>? impactList,
  String confirmLabel = MovementStrings.commonConfirm,
  String cancelLabel = MovementStrings.commonCancel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => MovementConfirmDialog(
      title: title,
      message: message,
      impactList: impactList,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  );
  return result ?? false;
}
