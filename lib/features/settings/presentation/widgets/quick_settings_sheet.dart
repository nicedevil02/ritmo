import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/security/app_lock_service.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
import 'package:ritmo/core/services/foreground_notification_updater.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo_adaptive_grid.dart';

class QuickSettingsSheet extends StatelessWidget {
  const QuickSettingsSheet({super.key, this.themeRepository});

  final ThemeRepository? themeRepository;

  static Future<void> show(BuildContext context, {ThemeRepository? themeRepository}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => QuickSettingsSheet(themeRepository: themeRepository),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);

    const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));

    final content = AnimatedBuilder(
      animation: SettingsService.instance.revision,
      builder: (context, _) {
        final themeMode = SettingsService.instance.get<String>('theme_mode');
        final isCurrentlyDark = themeMode == 'dark' ||
            (themeMode == 'system' &&
                Theme.of(context).brightness == Brightness.dark);
        final quiet = SettingsService.instance.get<bool>('notif_quiet_enabled');
        final persistent = SettingsService.instance.get<bool>(
          'persistent_status_notification_enabled',
        );
        final oled = SettingsService.instance.get<bool>('theme_true_black');
        final biometric = SettingsService.instance.get<bool>(
          'app_biometric_enabled',
        );
        final haptic = SettingsService.instance.get<bool>(
          'haptic_feedback_enabled',
        );

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 16,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.slider_horizontal_3,
                      color: colors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تنظیمات سریع',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                  const SizedBox(height: 8),
                  Text(
                    'دسترسی آنی به کلیدهای پرکاربرد برنامه',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  RitmoAdaptiveGrid(
                    minTileWidth: RitmoBreakpoints.tileMinWidthCompact,
                    spacing: 12,
                    maxColumns: 2,
                    children: [
                      _QuickTile(
                        keyName: 'quick_quiet_tile',
                        title: 'ساعات سکوت',
                        isActive: quiet,
                        icon: quiet
                            ? CupertinoIcons.moon_fill
                            : CupertinoIcons.moon,
                        activeColor: colors.primary,
                        onTap: () async {
                          RitmoHaptics.selection();
                          final nextVal = !quiet;
                          await SettingsService.instance.set(
                            'notif_quiet_enabled',
                            nextVal,
                          );
                          await AlarmSchedulerService.scheduleNextAlarms();
                          if (context.mounted) {
                            RitmoToast.show(
                              context,
                              nextVal
                                  ? 'ساعات سکوت فعال شد 🌙'
                                  : 'ساعات سکوت غیرفعال شد',
                              icon: nextVal
                                  ? CupertinoIcons.moon_fill
                                  : CupertinoIcons.moon,
                            );
                          }
                        },
                      ),
                      _QuickTile(
                        keyName: 'quick_persistent_tile',
                        title: 'اعلان دائمی',
                        isActive: persistent,
                        icon: persistent
                            ? CupertinoIcons.bell_fill
                            : CupertinoIcons.bell,
                        activeColor: colors.success,
                        onTap: () async {
                          RitmoHaptics.selection();
                          final nextVal = !persistent;
                          await SettingsService.instance.set(
                            'persistent_status_notification_enabled',
                            nextVal,
                          );
                          await ForegroundNotificationUpdater.update();
                          if (context.mounted) {
                            RitmoToast.show(
                              context,
                              nextVal
                                  ? 'اعلان دائمی وضعیت فعال شد 🔔'
                                  : 'اعلان دائمی وضعیت غیرفعال شد',
                              icon: nextVal
                                  ? CupertinoIcons.bell_fill
                                  : CupertinoIcons.bell,
                            );
                          }
                        },
                      ),
                      _QuickTile(
                        keyName: 'quick_theme_tile',
                        title: isCurrentlyDark ? 'حالت تیره' : 'حالت روشن',
                        isActive: isCurrentlyDark,
                        icon: isCurrentlyDark
                            ? CupertinoIcons.moon_stars_fill
                            : CupertinoIcons.sun_max_fill,
                        activeColor: colors.warning,
                        onTap: () async {
                          RitmoHaptics.selection();
                          final nextMode = isCurrentlyDark ? 'light' : 'dark';
                          await SettingsService.instance.set(
                            'theme_mode',
                            nextMode,
                          );
                          if (context.mounted) {
                            RitmoToast.show(
                              context,
                              nextMode == 'dark'
                                  ? 'حالت تیره فعال شد 🌙'
                                  : 'حالت روشن فعال شد ☀️',
                              icon: nextMode == 'dark'
                                  ? CupertinoIcons.moon_stars_fill
                                  : CupertinoIcons.sun_max_fill,
                            );
                          }
                        },
                      ),
                      _QuickTile(
                        keyName: 'quick_oled_tile',
                        title: 'سیاه OLED',
                        isActive: oled,
                        icon: CupertinoIcons.circle_filled,
                        activeColor: colors.textPrimary,
                        onTap: () async {
                          RitmoHaptics.selection();
                          final nextVal = !oled;
                          await SettingsService.instance.set(
                            'theme_true_black',
                            nextVal,
                          );
                          if (context.mounted) {
                            RitmoToast.show(
                              context,
                              nextVal
                                  ? 'حالت سیاه خالص (OLED) فعال شد 🖤'
                                  : 'حالت سیاه خالص (OLED) غیرفعال شد',
                              icon: CupertinoIcons.circle_filled,
                            );
                          }
                        },
                      ),
                      _QuickTile(
                        keyName: 'quick_biometric_tile',
                        title: 'قفل اثرانگشت',
                        isActive: biometric,
                        icon: CupertinoIcons.lock_shield_fill,
                        activeColor: colors.accent,
                        onTap: () async {
                          RitmoHaptics.selection();
                          if (!biometric) {
                            final supported = await AppLockService.instance
                                .isDeviceSupported();
                            final canCheck = await AppLockService.instance
                                .canCheckBiometrics();
                            if (!supported || !canCheck) {
                              if (context.mounted) {
                                RitmoToast.show(
                                  context,
                                  'دستگاه شما از حسگر اثر انگشت یا چهره پشتیبانی نمی‌کند.',
                                  icon: Icons.warning_amber_rounded,
                                );
                              }
                              return;
                            }
                            final password = await AppLockService.instance
                                .getLockPassword();
                            if (password == null || password.isEmpty) {
                              if (context.mounted) {
                                RitmoToast.show(
                                  context,
                                  'لطفاً ابتدا در بخش «امنیت و قفل برنامه»، رمز عبور تعیین کنید.',
                                  icon: Icons.lock_outline_rounded,
                                );
                              }
                              return;
                            }
                            final authenticated = await AppLockService.instance
                                .authenticateWithDevice(
                                  reason:
                                      'لطفاً برای فعال‌سازی قفل بیومتریک، هویت خود را تایید کنید',
                                  biometricOnly: true,
                                );
                            if (authenticated) {
                              await SettingsService.instance.set(
                                'app_biometric_enabled',
                                true,
                              );
                              await SettingsService.instance.set(
                                'app_lock_enabled',
                                true,
                              );
                              if (context.mounted) {
                                RitmoToast.show(
                                  context,
                                  'قفل اثرانگشت با موفقیت فعال شد 🔒',
                                  icon: CupertinoIcons.lock_shield_fill,
                                );
                              }
                            } else {
                              if (context.mounted) {
                                RitmoToast.show(
                                  context,
                                  'احراز هویت بیومتریک ناموفق بود.',
                                  icon: Icons.error_outline_rounded,
                                );
                              }
                            }
                          } else {
                            await SettingsService.instance.set(
                              'app_biometric_enabled',
                              false,
                            );
                            if (context.mounted) {
                              RitmoToast.show(
                                context,
                                'قفل اثرانگشت غیرفعال شد',
                                icon: CupertinoIcons.lock_shield,
                              );
                            }
                          }
                        },
                      ),
                      _QuickTile(
                        keyName: 'quick_haptic_tile',
                        title: 'بازخورد لرزشی',
                        isActive: haptic,
                        icon: CupertinoIcons.waveform_path,
                        activeColor: colors.secondary,
                        onTap: () async {
                          final nextVal = !haptic;
                          await SettingsService.instance.set(
                            'haptic_feedback_enabled',
                            nextVal,
                          );
                          if (nextVal) {
                            RitmoHaptics.selection();
                          }
                          if (context.mounted) {
                            RitmoToast.show(
                              context,
                              nextVal
                                  ? 'بازخورد لرزشی فعال شد 📳'
                                  : 'بازخورد لرزشی غیرفعال شد',
                              icon: CupertinoIcons.waveform_path,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isGlass
                          ? (isCurrentlyDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.white.withValues(alpha: 0.45))
                          : colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrentlyDark ? colors.border : colors.divider,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.textformat_size,
                          color: colors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'اندازهٔ متن',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        (() {
                          final currentScale = SettingsService.instance
                              .get<int>('ui_text_scale');
                          int selectedOption = 100;
                          if (currentScale <= 93) {
                            selectedOption = 93;
                          } else if (currentScale >= 125) {
                            selectedOption = 125;
                          }
                          final repo = themeRepository ?? ThemeRepository();

                          return SegmentedButton<int>(
                            segments: [
                              ButtonSegment(
                                value: 93,
                                label: Text(
                                  'کوچک',
                                  style: context.t.labelSmall,
                                ),
                              ),
                              ButtonSegment(
                                value: 100,
                                label: Text(
                                  'معمولی',
                                  style: context.t.labelSmall,
                                ),
                              ),
                              ButtonSegment(
                                value: 125,
                                label: Text(
                                  'بزرگ',
                                  style: context.t.labelSmall,
                                ),
                              ),
                            ],
                            selected: {selectedOption},
                            showSelectedIcon: false,
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.standard,
                              minimumSize: WidgetStatePropertyAll(
                                Size(0, RitmoBreakpoints.minTouchTarget),
                              ),
                            ),
                            onSelectionChanged: (val) async {
                              RitmoHaptics.selection();
                              await repo.updateTextScalePercent(val.first);
                            },
                          );
                        })(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

    final floatingShadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
        blurRadius: 28,
        spreadRadius: 0,
        offset: const Offset(0, -4),
      ),
    ];

    if (!isGlass) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: sheetRadius,
            boxShadow: floatingShadow,
            border: Border.all(
              color: isDark ? colors.border : colors.divider,
              width: 1.0,
            ),
          ),
          child: content,
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: sheetRadius,
          boxShadow: floatingShadow,
        ),
        child: ClipRRect(
          borderRadius: sheetRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.glassTint,
                borderRadius: sheetRadius,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.70),
                  width: 1.0,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: sheetRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(
                        alpha: isDark ? 0.08 : 0.20,
                      ),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.45],
                  ),
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.keyName,
    required this.title,
    required this.isActive,
    required this.icon,
    required this.activeColor,
    required this.onTap,
  });

  final String keyName;
  final String title;
  final bool isActive;
  final IconData icon;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;

    final inactiveBg = isGlass
        ? (isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.45))
        : colors.surface;

    final inactiveBorder = isDark ? colors.border : colors.divider;

    return GestureDetector(
      key: ValueKey(keyName),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: isDark ? 0.20 : 0.15)
              : inactiveBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.5)
                : inactiveBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? activeColor : colors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? colors.textPrimary : colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
