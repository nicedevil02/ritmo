// =============================================================================
//  cards_showcase_screen.dart
//  صفحه نمایش زنده و تست ویجت‌های سیستم مرجع کارت‌های ریتمو (Ritmo Universal Card System)
// =============================================================================

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';

class CardsShowcaseScreen extends StatefulWidget {
  const CardsShowcaseScreen({super.key});

  @override
  State<CardsShowcaseScreen> createState() => _CardsShowcaseScreenState();
}

class _CardsShowcaseScreenState extends State<CardsShowcaseScreen> {
  int _selectedCardIndex = 0;
  bool _taskDone = false;
  int _focusMinutes = 25;
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;

    return RitmoPageScaffold(
      appBar: RitmoModuleAppBar.fromContext(
        context: context,
        title: 'سیستم مرجع کارت‌های نئومورفیک',
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── هدر معرفی سیستم نئومورفیک ──
          _buildHeroHeader(colors, isDark),
          const SizedBox(height: 20),

          // ── ۱. کارت‌های برجسته نئومورفیک (Neumorphic Raised) ──
          _buildSectionTitle('۱. کارت برجسته نئومورفیک ۳ بعدی (Raised)', 'سایه دوگانه متضاد + گرادیان محدب ملایم'),
          const SizedBox(height: 10),

          // کارت نمونه ویجت داشبورد با المان‌های اتمیک نئومورفیک
          RitmoCard.neumorphic(
            onTap: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('کارت نئومورفیک لمس شد (انیمیشن فرورفتگی + لرزش اپل)'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RitmoCardHeader(
                  title: 'نبض ریتم روزانه',
                  subtitle: 'بررسی پیشرفت و فعالیت‌های فعال',
                  icon: CupertinoIcons.waveform_path_ecg,
                  iconColor: colors.primary,
                  trailing: RitmoCardBadge(
                    label: '۸۵٪ تکمیل',
                    color: colors.success,
                    icon: CupertinoIcons.checkmark_alt,
                  ),
                ),
                const SizedBox(height: 8),
                RitmoCardTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(CupertinoIcons.flame_fill, size: 17, color: colors.primary),
                  ),
                  title: 'زمان تمرکز عمیق',
                  subtitle: 'هدف امروز: ۲ ساعت',
                  trailing: Text(
                    toPersianDigits('$_focusMinutes دقیقه'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    setState(() => _focusMinutes += 5);
                  },
                ),
                const SizedBox(height: 8),
                RitmoCardTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(CupertinoIcons.checkmark_seal_fill, size: 17, color: colors.success),
                  ),
                  title: 'عادت‌های روزانه',
                  subtitle: '۳ از ۴ مورد انجام شده',
                  trailing: CupertinoSwitch(
                    value: _taskDone,
                    activeTrackColor: colors.success,
                    onChanged: (val) => setState(() => _taskDone = val),
                  ),
                ),
                const RitmoCardDivider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'برای فرورفتن و تست کلیک کنید',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textTertiary,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                    Icon(CupertinoIcons.chevron_left, size: 13, color: colors.textTertiary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── ۲. کارت‌ها در حالت انتخاب نئومورفیک (Selected State) ──
          _buildSectionTitle('۲. حالت انتخاب‌شده (Selected State)', 'گرادیان زنده پالت + هاله نوری نئومورفیک'),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: RitmoCard.neumorphic(
                  isSelected: _selectedCardIndex == 0,
                  onTap: () => setState(() => _selectedCardIndex = 0),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.sun_max_fill,
                        size: 26,
                        color: _selectedCardIndex == 0 ? Colors.white : colors.primary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'قلمرو روز',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _selectedCardIndex == 0 ? Colors.white : colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RitmoCardBadge(
                        label: 'فعال',
                        color: _selectedCardIndex == 0 ? Colors.white : colors.primary,
                        isOutlined: _selectedCardIndex == 0,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: RitmoCard.neumorphic(
                  isSelected: _selectedCardIndex == 1,
                  onTap: () => setState(() => _selectedCardIndex = 1),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.moon_stars_fill,
                        size: 26,
                        color: _selectedCardIndex == 1 ? Colors.white : colors.textSecondary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'قلمرو شب',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _selectedCardIndex == 1 ? Colors.white : colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RitmoCardBadge(
                        label: 'رزرو',
                        color: _selectedCardIndex == 1 ? Colors.white : colors.textSecondary,
                        isOutlined: _selectedCardIndex == 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── ۳. کارت فرورفته نئومورفیک (Sunken Inset) ──
          _buildSectionTitle('۳. سطح فرورفته نئومورفیک (Sunken Inset)', 'سایه معکوس برای اینپوت‌ها، پیش‌نمایش و گودی‌ها'),
          const SizedBox(height: 10),

          RitmoCard.neumorphicSunken(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(CupertinoIcons.info_circle_fill, size: 17, color: colors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'گودی نئومورفیک فیزیکی (Physical Inset)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'این کارت با سایه معکوس در زاویه ۱۳۵ درجه، حس فرورفتن در عمق بوم را شبیه‌سازی می‌کند و برای یادداشت‌ها یا ترک‌های پیشرفت عالی است.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── ۴. دکمه‌های نئومورفیک ۳ بعدی (Tactile 3D Buttons) ──
          _buildSectionTitle('۴. دکمه‌های نئومورفیک ۳ بعدی (Tactile Buttons)', 'فشردن فیزیکی با تغییر وضعیت به فرورفته'),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: RitmoNeuButton(
                  onTap: () => setState(() => _counter++),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.add_circled_solid, size: 18, color: colors.primary),
                      const SizedBox(width: 8),
                      Text(
                        toPersianDigits('شمارنده: $_counter'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RitmoNeuButton(
                  onTap: () => setState(() => _counter = 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.refresh_circled, size: 18, color: colors.error),
                      const SizedBox(width: 8),
                      Text(
                        'بازنشانی',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(RitmoColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.25),
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.cube_box_fill,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ویترین زنده سیستم مرجع نئومورفیک',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'عمق ۳ بعدی، سایه‌های دوگانه، فرورفتگی و برجستگی',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String desc) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          style: TextStyle(
            fontSize: 11,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
