import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// مدل اکشن‌های اکشن‌شیت شیشه‌ای ریتمو
class RitmoActionSheetItem {
  const RitmoActionSheetItem({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
    this.isDefault = false,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;
  final bool isDefault;
  final IconData? icon;
}

/// اکشن‌شیت شیشه‌ای اختصاصی ریتمو — منطبق بر Apple HIG و متریال آرورا
class RitmoGlassActionSheet extends StatelessWidget {
  const RitmoGlassActionSheet({
    super.key,
    this.title,
    this.message,
    required this.actions,
    this.cancelLabel = 'انصراف',
    this.onCancel,
  });

  final String? title;
  final String? message;
  final List<RitmoActionSheetItem> actions;
  final String cancelLabel;
  final VoidCallback? onCancel;

  /// نمایش شیت تایید خروج و دور انداختن تغییرات ذخیره‌نشده (Discard Changes)
  static Future<bool?> showDiscard({
    required BuildContext context,
    String title = 'تغییرات ذخیره نشده‌اند',
    String message = 'آیا از خروج و حذف تغییرات اطمینان دارید؟',
    String discardLabel = 'حذف تغییرات',
    String continueEditingLabel = 'ادامه ویرایش',
  }) {
    RitmoHaptics.warning();
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      isScrollControlled: true,
      builder: (ctx) => RitmoGlassActionSheet(
        title: title,
        message: message,
        actions: [
          RitmoActionSheetItem(
            label: discardLabel,
            isDestructive: true,
            icon: CupertinoIcons.trash_fill,
            onPressed: () {
              RitmoHaptics.tap();
              Navigator.of(ctx).pop(true);
            },
          ),
        ],
        cancelLabel: continueEditingLabel,
        onCancel: () {
          RitmoHaptics.tap();
          Navigator.of(ctx).pop(false);
        },
      ),
    );
  }

  /// متد عمومی باز کردن اکشن‌شیت شیشه‌ای
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? message,
    required List<RitmoActionSheetItem> actions,
    String cancelLabel = 'انصراف',
  }) {
    RitmoHaptics.tap();
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      isScrollControlled: true,
      builder: (ctx) => RitmoGlassActionSheet(
        title: title,
        message: message,
        actions: actions,
        cancelLabel: cancelLabel,
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final materialSpec = context.materials.regular;
    final isOpaque = !isGlass || highContrast;

    Widget buildGlassBox({required Widget child, BorderRadius? borderRadius}) {
      final br = borderRadius ?? BorderRadius.circular(20);
      final container = Container(
        decoration: BoxDecoration(
          color: isOpaque
              ? colors.surfaceElevated
              : (isDark
                  ? const Color(0xFF161B26).withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.90)),
          borderRadius: br,
          border: Border.all(
            color: isOpaque
                ? (isDark ? colors.border : colors.divider)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.95)),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );

      if (isOpaque) return container;

      return ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: materialSpec.sigma,
            sigmaY: materialSpec.sigma,
          ),
          child: container,
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Upper Main Actions Card
              buildGlassBox(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null || message != null) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (title != null)
                              Text(
                                title!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Vazirmatn',
                                  color: colors.textPrimary,
                                ),
                              ),
                            if (message != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                message!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Vazirmatn',
                                  color: colors.textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : colors.divider.withValues(alpha: 0.50),
                      ),
                    ],
                    ...actions.map((action) {
                      final itemColor = action.isDestructive
                          ? colors.error
                          : (action.isDefault ? colors.primary : colors.textPrimary);

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: action.onPressed,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (action.icon != null) ...[
                                  Icon(action.icon, size: 18, color: itemColor),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  action.label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: action.isDestructive || action.isDefault
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                    fontFamily: 'Vazirmatn',
                                    color: itemColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Bottom Separate Cancel Capsule
              buildGlassBox(
                borderRadius: BorderRadius.circular(18),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onCancel ?? () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      child: Text(
                        cancelLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Vazirmatn',
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
