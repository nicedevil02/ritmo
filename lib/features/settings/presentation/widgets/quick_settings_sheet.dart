import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';

class QuickSettingsSheet extends StatelessWidget {
  const QuickSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const QuickSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedBuilder(
      animation: SettingsService.instance.revision,
      builder: (context, _) {
        final quiet = SettingsService.instance.get<bool>('notif_quiet_enabled');
        final persistent = SettingsService.instance.get<bool>('persistent_status_notification_enabled');
        final themeMode = SettingsService.instance.get<String>('theme_mode');
        final isDark = themeMode == 'dark';
        final oled = SettingsService.instance.get<bool>('theme_true_black');
        final biometric = SettingsService.instance.get<bool>('app_biometric_enabled');
        final haptic = SettingsService.instance.get<bool>('haptic_feedback_enabled');

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 16,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: colors.border),
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
                    Icon(CupertinoIcons.slider_horizontal_3, color: colors.primary, size: 22),
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
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.2,
                  children: [
                    _QuickTile(
                      keyName: 'quick_quiet_tile',
                      title: 'ساعات سکوت',
                      isActive: quiet,
                      icon: quiet ? CupertinoIcons.moon_fill : CupertinoIcons.moon,
                      activeColor: const Color(0xFF6366F1),
                      onTap: () async {
                        RitmoHaptics.selection();
                        await SettingsService.instance.set('notif_quiet_enabled', !quiet);
                      },
                    ),
                    _QuickTile(
                      keyName: 'quick_persistent_tile',
                      title: 'اعلان دائمی',
                      isActive: persistent,
                      icon: persistent ? CupertinoIcons.bell_fill : CupertinoIcons.bell,
                      activeColor: const Color(0xFF10B981),
                      onTap: () async {
                        RitmoHaptics.selection();
                        await SettingsService.instance.set('persistent_status_notification_enabled', !persistent);
                      },
                    ),
                    _QuickTile(
                      keyName: 'quick_theme_tile',
                      title: isDark ? 'حالت تیره' : 'حالت روشن',
                      isActive: isDark,
                      icon: isDark ? CupertinoIcons.moon_stars_fill : CupertinoIcons.sun_max_fill,
                      activeColor: const Color(0xFFF59E0B),
                      onTap: () async {
                        RitmoHaptics.selection();
                        await SettingsService.instance.set('theme_mode', isDark ? 'light' : 'dark');
                      },
                    ),
                    _QuickTile(
                      keyName: 'quick_oled_tile',
                      title: 'سیاه OLED',
                      isActive: oled,
                      icon: CupertinoIcons.circle_filled,
                      activeColor: const Color(0xFF18181B),
                      onTap: () async {
                        RitmoHaptics.selection();
                        await SettingsService.instance.set('theme_true_black', !oled);
                      },
                    ),
                    _QuickTile(
                      keyName: 'quick_biometric_tile',
                      title: 'قفل اثرانگشت',
                      isActive: biometric,
                      icon: CupertinoIcons.lock_shield_fill,
                      activeColor: const Color(0xFFEC4899),
                      onTap: () async {
                        RitmoHaptics.selection();
                        await SettingsService.instance.set('app_biometric_enabled', !biometric);
                      },
                    ),
                    _QuickTile(
                      keyName: 'quick_haptic_tile',
                      title: 'بازخورد لرزشی',
                      isActive: haptic,
                      icon: CupertinoIcons.waveform_path,
                      activeColor: const Color(0xFF06B6D4),
                      onTap: () async {
                        RitmoHaptics.selection();
                        await SettingsService.instance.set('haptic_feedback_enabled', !haptic);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      },
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

    return GestureDetector(
      key: ValueKey(keyName),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.15) : colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? activeColor.withValues(alpha: 0.4) : colors.border,
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
