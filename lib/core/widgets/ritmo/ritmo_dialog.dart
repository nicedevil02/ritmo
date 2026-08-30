// Ritmo Dialog & Glass Dialog — دیالوگ تأیید، هشدار و مودال شیشه‌ای یکپارچه
// جایگزین رسمی AlertDialog های خام و مات

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';

class RitmoDialog extends StatelessWidget {
  const RitmoDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmLabel = 'تأیید',
    this.cancelLabel = 'انصراف',
    this.icon,
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
  });

  final String title;
  final String content;
  final String confirmLabel;
  final String cancelLabel;
  final IconData? icon;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  /// متد فراخوانی دیالوگ شیشه‌ای استاندارد با انیمیشن ورود و بلور زنده
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String content,
    String confirmLabel = 'تأیید',
    String cancelLabel = 'انصراف',
    IconData? icon,
    bool isDestructive = false,
  }) {
    if (isDestructive) {
      RitmoHaptics.warning();
    } else {
      RitmoHaptics.tap();
    }

    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      barrierDismissible: true,
      builder: (context) => RitmoDialog(
        title: title,
        content: content,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        icon: icon,
        isDestructive: isDestructive,
        onConfirm: () {
          RitmoHaptics.tap();
          Navigator.of(context).pop(true);
        },
        onCancel: () {
          RitmoHaptics.tap();
          Navigator.of(context).pop(false);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;

    final primaryAccent = isDestructive ? colors.error : colors.primary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 380),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF131722).withValues(alpha: 0.88)
                        : Colors.white.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.95),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.60 : 0.18),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: primaryAccent.withValues(alpha: isDark ? 0.12 : 0.08),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header with optional Icon & Title
                      Row(
                        children: [
                          if (icon != null) ...[
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(icon, size: 20, color: primaryAccent),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: isDestructive ? colors.error : colors.textPrimary,
                                fontFamily: 'Vazirmatn',
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Content description
                      Text(
                        content,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: colors.textSecondary,
                          height: 1.65,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),

                      const SizedBox(height: 22),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: RitmoSecondaryButton(
                              label: cancelLabel,
                              onPressed: onCancel ?? () {
                                RitmoHaptics.tap();
                                Navigator.of(context).pop(false);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RitmoPrimaryButton(
                              label: confirmLabel,
                              fullWidth: true,
                              onPressed: onConfirm ?? () {
                                RitmoHaptics.tap();
                                Navigator.of(context).pop(true);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
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

/// Alias برای هماهنگی با نام‌گذاری شیشه‌ای
typedef RitmoGlassDialog = RitmoDialog;
