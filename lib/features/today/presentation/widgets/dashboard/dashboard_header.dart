import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/shamsi_week.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/search/presentation/global_search_screen.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// هدر صفحهٔ خانه: سلامِ زمان‌محور + تاریخ جلالی + آواتار با هالهٔ گرادیان
/// و یک خوشهٔ اکشن (جستجو + اعلان‌ها). فقط لایهٔ نمایش.
///
/// دکمهٔ دستیار عمداً اینجا نیست: داک پایین یک تب اختصاصی دستیار دارد و
/// صفحهٔ خانه هم کارت بریفینگ دستیار را نشان میدهد؛ دکمهٔ سوم تکرار بود.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.userName,
    this.avatarPath,
    this.avatarFileExists = false,
    required this.unreadInboxCount,
    required this.onAvatarTap,
    required this.onBellTap,
    this.onSearchTap,
    @Deprecated('دستیار از داک پایین باز میشود؛ این پارامتر بیاثر است.')
    this.isAssistantActive = false,
    @Deprecated('دستیار از داک پایین باز میشود؛ این پارامتر بیاثر است.')
    this.onAssistantTap,
  });

  final String userName;
  final String? avatarPath;
  final bool avatarFileExists;
  final int unreadInboxCount;
  final VoidCallback onAvatarTap;
  final VoidCallback onBellTap;
  final VoidCallback? onSearchTap;

  /// نگهداشته شده فقط برای سازگاری با فراخوان‌های قدیمی.
  final bool isAssistantActive;

  /// نگهداشته شده فقط برای سازگاری با فراخوان‌های قدیمی.
  final VoidCallback? onAssistantTap;

  /// سلام زمان‌محور: صبح/ظهر/عصر/شب بخیر
  static ({String greeting, String emoji}) timeGreeting(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 12) return (greeting: 'صبح بخیر', emoji: '🌤');
    if (hour >= 12 && hour < 17) return (greeting: 'ظهر بخیر', emoji: '☀️');
    if (hour >= 17 && hour < 21) return (greeting: 'عصر بخیر', emoji: '🌇');
    return (greeting: 'شب بخیر', emoji: '🌙');
  }

  /// دکمه‌های اکشن دایره‌ای سبک ماژول‌های ریتمو
  Widget _buildHeaderActionButton({
    required IconData icon,
    required bool isDark,
    required RitmoColors colors,
    required VoidCallback onTap,
    String? tooltip,
    Widget? badge,
  }) {
    final button = GestureDetector(
      onTap: () {
        RitmoHaptics.tap();
        onTap();
      },
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF22262E) : const Color(0xFFF3F5F8),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 0.8,
          ),
        ),
        child: Center(
          child: badge ??
              Icon(
                icon,
                color: isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
                size: 18,
              ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  /// زنگوله با نشان شمارش — بالای ۹ به «۹+» خلاصه میشود.
  Widget _bellGlyph(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Icon(
          CupertinoIcons.bell,
          color: isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
          size: 18,
        ),
        if (unreadInboxCount > 0)
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(RitmoRadius.pill),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E222A) : Colors.white,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  unreadInboxCount > 9
                      ? '۹+'
                      : toPersianDigits(unreadInboxCount.toString()),
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 9.0,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    // تاریخ
    final String dateStr;
    if (locale.languageCode == 'fa') {
      final jalali = Jalali.now();
      dateStr =
          '${ShamsiWeek.nameOf(jalali.weekDay)} ${toPersianDigits(jalali.day.toString())} ${jalali.formatter.mN}';
    } else {
      final now = DateTime.now();
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      dateStr =
          '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
    }

    final tg = timeGreeting(DateTime.now());
    final greetingLine = locale.languageCode == 'fa'
        ? '${tg.greeting}، $userName'
        : l10n.welcomeUser(userName);

    // G-4: وجود فایل بهصورت async در صفحه محاسبه و بهعنوان پارامتر پاس داده میشود؛
    // existsSync داخل build حذف شد (I/O دیسک در هر rebuild).
    final hasAvatarFile =
        avatarFileExists && avatarPath != null && avatarPath!.isNotEmpty;

    return RitmoGlassHeader(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
              children: [
                // آواتار با هالهٔ گرادیان انرژی
                Semantics(
                  button: true,
                  label: 'پروفایل و تنظیمات',
                  child: GestureDetector(
                    onTap: () {
                      RitmoHaptics.tap();
                      onAvatarTap();
                    },
                    child: Container(
                      height: 38,
                      width: 38,
                      padding: const EdgeInsets.all(1.8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: colors.energyGradient),
                        boxShadow: [
                          BoxShadow(
                            color: colors.energyGradient.first.withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.bg,
                          image: hasAvatarFile
                              ? DecorationImage(
                                  image: ResizeImage(
                                    FileImage(File(avatarPath!)),
                                    width: 120,
                                    height: 120,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: hasAvatarFile
                            ? null
                            : Center(
                                child: Text(
                                  userName.isNotEmpty ? userName[0] : '؟',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // سلام و تاریخ
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              greetingLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                                letterSpacing: -0.3,
                                color: isDark ? Colors.white : const Color(0xFF1D2129),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(tg.emoji, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        toPersianDigits(dateStr),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // دکمه‌های اکشن دایره‌ای سبک ماژول‌ها (جستجو و زنگوله)
                _buildHeaderActionButton(
                  icon: CupertinoIcons.search,
                  tooltip: 'جستجو',
                  isDark: isDark,
                  colors: colors,
                  onTap: () {
                    if (onSearchTap != null) {
                      onSearchTap!();
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GlobalSearchScreen(),
                        ),
                      );
                    }
                  },
                ),
                _buildHeaderActionButton(
                  icon: CupertinoIcons.bell,
                  tooltip: 'اعلان‌ها',
                  isDark: isDark,
                  colors: colors,
                  badge: _bellGlyph(context),
                  onTap: onBellTap,
                ),
                const SizedBox(width: 2),
              ],
            ),
    );
  }
}
