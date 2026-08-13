import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
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

  /// یک دکمهٔ داخل خوشهٔ شیشهای.
  Widget _pillAction({
    required Widget child,
    required VoidCallback onTap,
    String? semanticLabel,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            RitmoHaptics.tap();
            onTap();
          },
          child: SizedBox(
            height: 44,
            width: 44,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  /// زنگوله با نشان شمارش — بالای ۹ به «۹+» خلاصه میشود.
  Widget _bellGlyph(BuildContext context) {
    final colors = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(CupertinoIcons.bell, color: colors.textPrimary, size: 20),
        if (unreadInboxCount > 0)
          Positioned(
            top: -5,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(RitmoRadius.pill),
                border: Border.all(
                  color: colors.bg.withValues(alpha: 0.9),
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
                    fontSize: 9.5,
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
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    // تاریخ
    final String dateStr;
    if (locale.languageCode == 'fa') {
      final jalali = Jalali.now();
      dateStr = '${jalali.formatter.wN} ${jalali.day} ${jalali.formatter.mN}';
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

    return Row(
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
              height: 46,
              width: 46,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: colors.energyGradient),
                boxShadow: [
                  BoxShadow(
                    color: colors.energyGradient.first.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.bg,
                  image: hasAvatarFile
                      ? DecorationImage(
                          image: FileImage(File(avatarPath!)),
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
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: colors.primary,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: RitmoSpacing.md),

        // سلام و تاریخ
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: RitmoSpacing.xs),
                  Text(tg.emoji, style: const TextStyle(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                toPersianDigits(dateStr),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.25,
                  letterSpacing: 0.1,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: RitmoSpacing.sm),

        // خوشهٔ اکشن: جستجو + اعلان‌ها در یک قرص شیشهای واحد
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(RitmoRadius.pill),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pillAction(
                semanticLabel: 'جستجو',
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
                child: Icon(
                  CupertinoIcons.search,
                  color: colors.textSecondary,
                  size: 19,
                ),
              ),
              Container(
                width: 1,
                height: 20,
                color: colors.border,
              ),
              _pillAction(
                semanticLabel: 'اعلان‌ها',
                onTap: onBellTap,
                child: _bellGlyph(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
