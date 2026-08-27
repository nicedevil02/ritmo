// صفحهٔ تنظیمات تم با انتخاب پالت و پیش‌نمایش زنده (فاز ۳)
// جایگزین شیت قدیمی انتخاب تم

import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_preferences.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_segmented_control.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({
    super.key,
    required this.themeRepository,
  });

  final ThemeRepository themeRepository;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ValueListenableBuilder<ThemePreferences>(
      valueListenable: themeRepository.preferencesNotifier,
      builder: (context, prefs, _) {
        return RitmoPageScaffold(
          appBar: RitmoModuleAppBar.fromContext(
            context: context,
            title: 'ظاهر و تم',
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ۱. حالت روشنایی
                Text(
                  'حالت روشنایی',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                    ),
                ),
                const SizedBox(height: RitmoSpacing.sm),
                RitmoSegmentedControl<ThemeMode>(
                  segments: const {
                    ThemeMode.system: 'هماهنگ با سیستم',
                    ThemeMode.light: 'روشن',
                    ThemeMode.dark: 'تاریک',
                  },
                  selected: prefs.mode,
                  onSelected: (mode) async {
                    await themeRepository.updateThemeMode(mode);
                  },
                ),
                const SizedBox(height: RitmoSpacing.xl),

                // ۲. پالت رنگی
                Text(
                  'پالت رنگی',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                    ),
                ),
                const SizedBox(height: RitmoSpacing.sm),
                ...RitmoPalette.all.map((palette) {
                  final isSelected = palette.id == prefs.paletteId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: RitmoSpacing.md),
                    child: _PalettePreviewCard(
                      palette: palette,
                      isSelected: isSelected,
                      onTap: () async {
                        final oldPalette = prefs.paletteId;
                        final success = await themeRepository.updatePalette(palette.id);
                        if (success && context.mounted) {
                          RitmoToast.show(
                            context,
                            'پالت به «${palette.nameFa}» تغییر کرد',
                            icon: Icons.palette_rounded,
                            iconColor: palette.dark.primary,
                            onUndo: () {
                              themeRepository.updatePalette(oldPalette);
                            },
                          );
                        } else if (!success && context.mounted) {
                          RitmoToast.show(
                            context,
                            'ذخیرهٔ تنظیمات ناموفق بود',
                            icon: Icons.error_outline_rounded,
                            iconColor: colors.error,
                          );
                        }
                      },
                    ),
                  );
                }),
                const SizedBox(height: RitmoSpacing.xl),

                // ۳. تنظیمات پیشرفته
                Text(
                  'تنظیمات پیشرفته',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                    ),
                ),
                const SizedBox(height: RitmoSpacing.sm),
                RitmoCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          value: !prefs.reduceTransparency,
                          onChanged: (val) {
                            themeRepository.updateReduceTransparency(!val);
                          },
                          title: Text(
                            'متریال شیشه‌ای (بلور)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'افکت بلور و شفافیت در کارت‌ها و پس‌زمینه (خاموش برای گوشی‌های ضعیف‌تر)',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                          activeTrackColor: colors.primary,
                        ),
                      ),
                      if (!prefs.reduceTransparency) ...[
                        Divider(color: colors.divider, height: 1),
                        // پیش‌نمایش زنده متریال شیشه‌ای (طراحی بر پایه Apple VisionOS / HIG)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: RitmoSpacing.lg,
                            vertical: RitmoSpacing.sm,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(RitmoRadius.card),
                            child: Container(
                              height: 135,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: context.isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF1F5F9),
                              ),
                              child: Stack(
                                children: [
                                  // ۱. گوی نورانی پرکنتراست گرم (آمبر / نارنجی) در سمت راست
                                  Positioned(
                                    top: 12,
                                    right: 8,
                                    child: Container(
                                      width: 110,
                                      height: 110,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            Color(0xFFFF9233),
                                            Color(0xFFFF5200),
                                            Colors.transparent,
                                          ],
                                          stops: [0.35, 0.85, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // ۲. گوی نورانی فیروزه‌ای / زمردی در سمت چپ
                                  Positioned(
                                    bottom: -15,
                                    left: 20,
                                    child: Container(
                                      width: 105,
                                      height: 105,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            const Color(0xFF00E5FF).withValues(alpha: 0.8),
                                            colors.primary.withValues(alpha: 0.5),
                                            Colors.transparent,
                                          ],
                                          stops: const [0.2, 0.7, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // ۳. کارت شناور شیشه‌ای با هم‌پوشانی نوری
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 12,
                                        top: 10,
                                        bottom: 10,
                                        right: 32,
                                      ),
                                      child: RitmoGlassCard(
                                        borderRadius: BorderRadius.circular(16),
                                        blurSigma: prefs.glassBlurSigma,
                                        color: (context.isDark ? Colors.black : Colors.white).withValues(
                                          alpha: (prefs.glassOpacityPercent / 100.0).clamp(0.05, 0.95),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              // ردیف نشان کپسولی مات بالا
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: (context.isDark ? Colors.white : Colors.black)
                                                          .withValues(alpha: 0.90),
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.auto_awesome,
                                                          size: 13,
                                                          color: context.isDark ? Colors.black : Colors.white,
                                                        ),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          'متریال شیشه‌ای پرمیوم',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: context.isDark ? Colors.black : Colors.white,
                                                            fontFamily: 'Vazirmatn',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Text(
                                                    'پیش‌نمایش زنده',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: colors.textSecondary.withValues(alpha: 0.8),
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              // ردیف آمار و شاخص‌های بلور و شفافیت
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: colors.primary.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(10),
                                                      border: Border.all(
                                                        color: colors.primary.withValues(alpha: 0.3),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          'بلور (ماتی): ',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: colors.textPrimary.withValues(alpha: 0.7),
                                                            fontFamily: 'Vazirmatn',
                                                          ),
                                                        ),
                                                        Text(
                                                          '${prefs.glassBlurSigma.round()}px',
                                                          style: TextStyle(
                                                            fontSize: 11.5,
                                                            fontWeight: FontWeight.bold,
                                                            color: colors.primary,
                                                            fontFamily: 'Vazirmatn',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFF9E44).withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(10),
                                                      border: Border.all(
                                                        color: const Color(0xFFFF9E44).withValues(alpha: 0.3),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          'شفافیت: ',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: colors.textPrimary.withValues(alpha: 0.7),
                                                            fontFamily: 'Vazirmatn',
                                                          ),
                                                        ),
                                                        Text(
                                                          '${prefs.glassOpacityPercent}٪',
                                                          style: const TextStyle(
                                                            fontSize: 11.5,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFFFF9E44),
                                                            fontFamily: 'Vazirmatn',
                                                          ),
                                                        ),
                                                      ],
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
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: RitmoSpacing.lg,
                            vertical: RitmoSpacing.sm,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'میزان مات بودن شیشه (بلور)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${prefs.glassBlurSigma.round()}px',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: prefs.glassBlurSigma.clamp(0.0, 40.0),
                                min: 0,
                                max: 40,
                                divisions: 40,
                                activeColor: colors.primary,
                                inactiveColor: colors.border,
                                onChanged: (val) {
                                  themeRepository.updateGlassBlurSigma(val);
                                },
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: RitmoSpacing.lg,
                            vertical: RitmoSpacing.sm,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'میزان شفافیت شیشه',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${prefs.glassOpacityPercent}٪',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: prefs.glassOpacityPercent
                                    .toDouble()
                                    .clamp(10.0, 85.0),
                                min: 10,
                                max: 85,
                                divisions: 15,
                                activeColor: colors.primary,
                                inactiveColor: colors.border,
                                onChanged: (val) {
                                  themeRepository
                                      .updateGlassOpacityPercent(val.round());
                                },
                              ),
                            ],
                          ),
                        ),
                        // دکمه بازگردانی به مقادیر پیش‌فرض شیشه
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: RitmoSpacing.lg,
                            vertical: RitmoSpacing.xs,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                RitmoHapticsPolicy.selection();
                                themeRepository.resetGlassSettings();
                              },
                              icon: Icon(
                                Icons.restart_alt_rounded,
                                size: 16,
                                color: colors.primary,
                              ),
                              label: Text(
                                'بازگردانی به پیش‌فرض',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary,
                                  fontFamily: 'Vazirmatn',
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                backgroundColor: colors.primary.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                        ),
                      ],
                      Divider(color: colors.divider, height: 1),
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          value: prefs.trueBlack,
                          onChanged: prefs.mode == ThemeMode.light
                              ? null
                              : (val) {
                                  themeRepository.updateTrueBlack(val);
                                },
                          title: Text(
                            'مشکی مطلق',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: prefs.mode == ThemeMode.light
                                  ? colors.disabled
                                  : colors.textPrimary,
                              ),
                          ),
                          subtitle: Text(
                            prefs.mode == ThemeMode.light
                                ? 'فقط در حالت تاریک اثر دارد'
                                : 'در حالت تاریک، پس‌زمینه کاملاً مشکی می‌شود. مناسب نمایشگر AMOLED',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                              ),
                          ),
                          activeTrackColor: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: RitmoSpacing.lg),

                // دکمه بازنشانی
                Center(
                  child: TextButton(
                    onPressed: () async {
                      await themeRepository.resetAppearance();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تنظیمات ظاهر به حالت پیش‌فرض بازگشت'),
                          ),
                        );
                      }
                    },
                    child: Text(
                      'بازگرداندن به حالت پیش‌فرض',
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.error,
                        ),
                    ),
                  ),
                ),
                const SizedBox(height: RitmoSpacing.xxl),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PalettePreviewCard extends StatelessWidget {
  const _PalettePreviewCard({
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

  final RitmoPalette palette;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeBrightness = Theme.of(context).brightness;

    return Theme(
      data: RitmoTheme.build(
        palette: palette,
        brightness: activeBrightness,
      ),
      child: Builder(
        builder: (innerContext) {
          final innerColors = innerContext.colors;

          return Semantics(
            label: 'پالت ${palette.nameFa}',
            selected: isSelected,
            button: true,
            child: GestureDetector(
              onTap: () {
                RitmoHapticsPolicy.selection();
                onTap();
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: RitmoMotion.state,
                padding: const EdgeInsets.all(RitmoSpacing.lg),
                decoration: BoxDecoration(
                  color: innerColors.surface,
                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                  border: Border.all(
                    color: isSelected
                        ? innerColors.primary
                        : (activeBrightness == Brightness.dark
                            ? innerColors.border
                            : innerColors.divider),
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  boxShadow: activeBrightness == Brightness.dark
                      ? RitmoElevation.none
                      : RitmoElevation.cardLight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row with 3 dots & checkmark
                    Row(
                      children: [
                        _ColorDot(color: innerColors.primary),
                        const SizedBox(width: RitmoSpacing.xs),
                        _ColorDot(color: innerColors.accent),
                        const SizedBox(width: RitmoSpacing.xs),
                        _ColorDot(color: innerColors.surfaceElevated),
                        const Spacer(),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: innerColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: innerColors.onPrimary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: RitmoSpacing.md),

                    // Sample Title & Subtitle
                    Text(
                      'نمونه عنوان کارت',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: innerColors.textPrimary,
                        ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'این پیش‌نمایش نحوه رندر رنگ‌های پالت را نشان می‌دهد',
                      style: TextStyle(
                        fontSize: 12,
                        color: innerColors.textSecondary,
                        ),
                    ),
                    const SizedBox(height: RitmoSpacing.md),

                    // Sample button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: innerColors.primary,
                        borderRadius: BorderRadius.circular(RitmoRadius.field),
                      ),
                      child: Text(
                        'دکمه نمونه',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: innerColors.onPrimary,
                          ),
                      ),
                    ),
                    const SizedBox(height: RitmoSpacing.md),

                    // 8 Module color circles
                    Row(
                      children: List.generate(8, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(left: RitmoSpacing.xs),
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: innerColors.modules.bySlot(i),
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: RitmoSpacing.md),

                    // Name & Tagline
                    Text(
                      '${palette.nameFa} · ${palette.taglineFa}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: innerColors.textPrimary,
                        ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12, width: 0.5),
      ),
    );
  }
}
