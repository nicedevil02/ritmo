import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_preferences.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/features/settings/presentation/cards_showcase_screen.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_section.dart';

class AppearanceGroupScreen extends StatefulWidget {
  final String? highlightKey;

  const AppearanceGroupScreen({
    super.key,
    required this.themeRepository,
    required this.localeRepository,
    this.highlightKey,
  });

  final ThemeRepository themeRepository;
  final LocaleRepository localeRepository;

  @override
  State<AppearanceGroupScreen> createState() => _AppearanceGroupScreenState();
}

class _AppearanceGroupScreenState extends State<AppearanceGroupScreen> {
  String _locale = 'fa';

  @override
  void initState() {
    super.initState();
    _locale = SettingsService.instance.get<String>('locale');
  }

  Future<void> _changeLocale(String loc) async {
    setState(() => _locale = loc);
    await widget.localeRepository.updateLocale(Locale(loc));
  }

  Widget _buildLivePreview(
    BuildContext context,
    RitmoColors colors,
    ThemePreferences prefs,
  ) {
    final previewScale = RitmoUiScale.effectiveTextScale(
      osScale: MediaQuery.textScalerOf(context).scale(1.0),
      appPercent: prefs.textScalePercent,
      followOs: prefs.followOsTextScale,
    );
    final m = RitmoMetrics.of(prefs.density);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: m.spaceLg, vertical: m.spaceSm),
      child: RitmoCard(
        padding: EdgeInsets.all(m.spaceMd),
        borderRadius: BorderRadius.circular(m.radiusCard),
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(previewScale)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'پیش‌نمایش زنده',
                    style:
                        context.t.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ) ??
                        TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: m.spaceSm,
                      vertical: m.spaceXs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(RitmoRadius.pill),
                    ),
                    child: Text(
                      'چیپ نمونه',
                      style:
                          context.t.labelSmall?.copyWith(
                            color: colors.primary,
                          ) ??
                          TextStyle(color: colors.primary),
                    ),
                  ),
                ],
              ),
              SizedBox(height: m.spaceSm),
              Text(
                'این یک متن نمونه برای مشاهدهٔ تأثیر تغییرات اندازهٔ قلم و فاصله در رابط کاربری است.',
                style:
                    context.t.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ) ??
                    TextStyle(color: colors.textSecondary),
              ),
              SizedBox(height: m.spaceMd),
              Row(
                children: [
                  Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    size: m.iconMd,
                    color: colors.success,
                  ),
                  SizedBox(width: m.spaceSm),
                  Expanded(
                    child: Text(
                      'ردیف لیست با هدف لمس استاندارد',
                      style:
                          context.t.bodyMedium?.copyWith(
                            color: colors.textPrimary,
                          ) ??
                          TextStyle(color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
              SizedBox(height: m.spaceMd),
              SizedBox(
                width: double.infinity,
                height: m.touchTarget,
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(m.radiusField),
                    ),
                  ),
                  child: Text(
                    'دکمهٔ تعاملی نمونه',
                    style:
                        context.t.labelLarge?.copyWith(
                          color: colors.onPrimary,
                        ) ??
                        TextStyle(color: colors.onPrimary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;

    return ValueListenableBuilder<ThemePreferences>(
      valueListenable: widget.themeRepository.preferencesNotifier,
      builder: (context, prefs, _) {
        return RitmoPageScaffold(
          padding: EdgeInsets.zero,
          appBar: RitmoModuleAppBar.fromContext(
            context: context,
            title: 'ظاهر و زبان',
          ),
          body: SingleChildScrollView(
            padding: EdgeInsetsDirectional.fromSTEB(
              m.spaceLg,
              m.spaceMd,
              m.spaceLg,
              m.navBarHeight + m.spaceSm,
            ),
            child: Column(
              children: [
                SettingsSection(
                  title: 'اندازهٔ متن و المان‌ها',
                  children: [
                    _buildLivePreview(context, colors, prefs),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: m.spaceLg,
                        vertical: m.spaceXs,
                      ),
                      child: RitmoCardTile(
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            CupertinoIcons.square_stack_3d_up_fill,
                            size: 17,
                            color: colors.primary,
                          ),
                        ),
                        title: 'ویترین سیستم مرجع کارت‌ها',
                        subtitle: 'مشاهده و تست استایل‌ها و فیزیک کارت‌های ریتمو',
                        trailing: Icon(
                          CupertinoIcons.chevron_left,
                          size: 14,
                          color: colors.textTertiary,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => const CardsShowcaseScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: m.spaceLg,
                        vertical: m.spaceSm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'اندازهٔ متن',
                                style:
                                    context.t.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ) ??
                                    TextStyle(color: colors.textPrimary),
                              ),
                              Text(
                                '${RitmoUiScale.textLabelFor(prefs.textScalePercent)} (${prefs.textScalePercent}٪)',
                                style:
                                    context.t.bodySmall?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.bold,
                                    ) ??
                                    TextStyle(color: colors.primary),
                              ),
                            ],
                          ),
                          Semantics(
                            label: 'اندازهٔ متن',
                            value:
                                '${RitmoUiScale.textLabelFor(prefs.textScalePercent)} ${prefs.textScalePercent} درصد',
                            child: Slider(
                              value: RitmoUiScale.stepIndexFromPercent(
                                prefs.textScalePercent,
                              ).toDouble(),
                              min: 0,
                              max: (RitmoUiScale.textSteps.length - 1)
                                  .toDouble(),
                              divisions: RitmoUiScale.textSteps.length - 1,
                              activeColor: colors.primary,
                              onChanged: (val) {
                                final stepped =
                                    RitmoUiScale.percentFromStepIndex(
                                      val.round(),
                                    );
                                if (stepped != prefs.textScalePercent) {
                                  RitmoHapticsPolicy.selection();
                                  widget.themeRepository.updateTextScalePercent(
                                    stepped,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: m.spaceLg,
                        vertical: m.spaceMd,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'پیروی از اندازه فونت سیستم',
                                  style:
                                      context.t.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ) ??
                                      TextStyle(color: colors.textPrimary),
                                ),
                                SizedBox(height: m.spaceXs),
                                Text(
                                  'اگر روشن باشد، اندازهٔ انتخابی شما در تنظیم سیستم دستگاه ضرب می‌شود.',
                                  style:
                                      context.t.bodySmall?.copyWith(
                                        color: colors.textSecondary,
                                      ) ??
                                      TextStyle(color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: m.spaceMd),
                          CupertinoSwitch(
                            value: prefs.followOsTextScale,
                            activeTrackColor: colors.primary,
                            onChanged: (val) {
                              RitmoHapticsPolicy.selection();
                              widget.themeRepository.updateFollowOsTextScale(
                                val,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: m.spaceLg,
                        vertical: m.spaceMd,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'چگالی و بزرگی المان‌ها',
                            style:
                                context.t.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ) ??
                                TextStyle(color: colors.textPrimary),
                          ),
                          SizedBox(height: m.spaceXs),
                          Text(
                            'تنظیم فواصل، دکمه‌ها، آیکن‌ها و اهداف لمس در برنامه',
                            style:
                                context.t.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ) ??
                                TextStyle(color: colors.textSecondary),
                          ),
                          SizedBox(height: m.spaceMd),
                          RitmoSegmentedControl<RitmoDensityLevel>(
                            selected: prefs.density,
                            segments: {
                              RitmoDensityLevel.compact:
                                  RitmoUiScale.densityLabelFor(
                                    RitmoDensityLevel.compact,
                                  ),
                              RitmoDensityLevel.comfortable:
                                  RitmoUiScale.densityLabelFor(
                                    RitmoDensityLevel.comfortable,
                                  ),
                              RitmoDensityLevel.spacious:
                                  RitmoUiScale.densityLabelFor(
                                    RitmoDensityLevel.spacious,
                                  ),
                              RitmoDensityLevel.xl:
                                  RitmoUiScale.densityLabelFor(
                                    RitmoDensityLevel.xl,
                                  ),
                            },
                            onSelected: (level) {
                              RitmoHapticsPolicy.selection();
                              widget.themeRepository.updateDensity(level);
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: m.spaceLg,
                        vertical: m.spaceSm,
                      ),
                      child: Center(
                        child: TextButton.icon(
                          icon: Icon(
                            CupertinoIcons.arrow_counterclockwise,
                            size: m.iconSm,
                          ),
                          label: const Text('بازگردانی به پیش‌فرض'),
                          style: TextButton.styleFrom(
                            foregroundColor: colors.textSecondary,
                            minimumSize: Size(m.touchTarget, m.touchTarget),
                          ),
                          onPressed: () {
                            RitmoHapticsPolicy.selection();
                            widget.themeRepository.resetAppearance();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                // ۲. حالت روشنایی
                SettingsSection(
                  title: 'حالت روشنایی',
                  children: [
                    Padding(
                      padding: EdgeInsets.all(m.spaceLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'انتخاب تم محیط برنامه',
                            style:
                                context.t.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ) ??
                                TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                          ),
                          SizedBox(height: m.spaceMd),
                          RitmoSegmentedControl<ThemeMode>(
                            segments: const {
                              ThemeMode.system: 'هماهنگ با سیستم',
                              ThemeMode.light: 'روشن',
                              ThemeMode.dark: 'تاریک',
                            },
                            selected: prefs.mode,
                            onSelected: (mode) async {
                              RitmoHapticsPolicy.selection();
                              await widget.themeRepository.updateThemeMode(
                                mode,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ۳. پالت‌های رنگی اختصاصی
                SettingsSection(
                  title: 'پالت‌های رنگی اختصاصی',
                  children: [
                    Padding(
                      padding: EdgeInsets.all(m.spaceLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'پالت رنگی مورد علاقه خود را انتخاب کنید:',
                            style:
                                context.t.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ) ??
                                TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                          ),
                          SizedBox(height: m.spaceMd),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: RitmoPalette.all.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              mainAxisExtent: 160,
                            ),
                            itemBuilder: (context, index) {
                              final palette = RitmoPalette.all[index];
                              final isSelected = palette.id == prefs.paletteId;
                              return _PalettePreviewCard(
                                palette: palette,
                                isSelected: isSelected,
                                onTap: () async {
                                  final oldPalette = prefs.paletteId;
                                  final success = await widget.themeRepository
                                      .updatePalette(palette.id);
                                  if (success && context.mounted) {
                                    RitmoToast.show(
                                      context,
                                      'پالت به «${palette.nameFa}» تغییر کرد',
                                      icon: Icons.palette_rounded,
                                      iconColor: palette.dark.primary,
                                      onUndo: () {
                                        widget.themeRepository.updatePalette(
                                          oldPalette,
                                        );
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
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ۴. جلوه‌های بصری و نمایشگر
                SettingsSection(
                  title: 'جلوه‌های بصری و نمایشگر',
                  children: [
                    // ۱. متریال شیشه‌ای
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: m.spaceLg,
                        vertical: m.spaceMd,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'متریال شیشه‌ای (بلور)',
                                  style:
                                      context.t.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ) ??
                                      TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                ),
                                SizedBox(height: m.spaceXs),
                                Text(
                                  'افکت بلور و شفافیت در کارت‌ها و پس‌زمینه (خاموش برای گوشی‌های ضعیف‌تر)',
                                  style:
                                      context.t.bodySmall?.copyWith(
                                        color: colors.textSecondary,
                                      ) ??
                                      TextStyle(color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: m.spaceMd),
                          CupertinoSwitch(
                            value: !prefs.reduceTransparency,
                            activeTrackColor: colors.primary,
                            onChanged: (val) {
                              RitmoHapticsPolicy.selection();
                              widget.themeRepository.updateReduceTransparency(
                                !val,
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    if (!prefs.reduceTransparency) ...[
                      // پیش‌نمایش زنده متریال شیشه‌ای (طراحی بر پایه Apple VisionOS / HIG)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: m.spaceLg,
                          vertical: m.spaceSm,
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

                      // اسلایدر میزان مات بودن شیشه (بلور)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: m.spaceLg,
                          vertical: m.spaceSm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'میزان مات بودن شیشه (بلور)',
                                  style: context.t.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${prefs.glassBlurSigma.round()} پیکسل',
                                  style: TextStyle(
                                    color: colors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    fontFamily: 'Vazirmatn',
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: m.spaceXs),
                            Slider(
                              value: prefs.glassBlurSigma.clamp(0.0, 40.0),
                              min: 0,
                              max: 40,
                              divisions: 40,
                              activeColor: colors.primary,
                              inactiveColor: colors.border,
                              onChanged: (val) {
                                widget.themeRepository.updateGlassBlurSigma(val);
                              },
                            ),
                          ],
                        ),
                      ),

                      // اسلایدر میزان شفافیت / غلظت شیشه
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: m.spaceLg,
                          vertical: m.spaceSm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'میزان شفافیت شیشه',
                                  style: context.t.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${prefs.glassOpacityPercent}٪',
                                  style: TextStyle(
                                    color: colors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    fontFamily: 'Vazirmatn',
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: m.spaceXs),
                            Slider(
                              value: prefs.glassOpacityPercent.toDouble().clamp(10.0, 85.0),
                              min: 10,
                              max: 85,
                              divisions: 15,
                              activeColor: colors.primary,
                              inactiveColor: colors.border,
                              onChanged: (val) {
                                widget.themeRepository.updateGlassOpacityPercent(val.round());
                              },
                            ),
                          ],
                        ),
                      ),

                      // دکمه بازگردانی به مقادیر پیش‌فرض شیشه
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: m.spaceLg,
                          vertical: m.spaceXs,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              RitmoHapticsPolicy.selection();
                              widget.themeRepository.resetGlassSettings();
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

                    // ۲. سیاه خالص OLED
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: m.spaceLg,
                        vertical: m.spaceMd,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'سیاه خالص (OLED)',
                                  style:
                                      context.t.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: prefs.mode == ThemeMode.light
                                            ? colors.disabled
                                            : colors.textPrimary,
                                      ) ??
                                      TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: prefs.mode == ThemeMode.light
                                            ? colors.disabled
                                            : colors.textPrimary,
                                      ),
                                ),
                                SizedBox(height: m.spaceXs),
                                Text(
                                  prefs.mode == ThemeMode.light
                                      ? 'فقط در حالت تاریک اثر دارد'
                                      : 'پس‌زمینه کاملاً مشکی در حالت تاریک جهت صرفه‌جویی در باتری',
                                  style:
                                      context.t.bodySmall?.copyWith(
                                        color: colors.textSecondary,
                                      ) ??
                                      TextStyle(color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: m.spaceMd),
                          CupertinoSwitch(
                            value: prefs.trueBlack,
                            activeTrackColor: colors.primary,
                            onChanged: prefs.mode == ThemeMode.light
                                ? null
                                : (val) {
                                    RitmoHapticsPolicy.selection();
                                    widget.themeRepository.updateTrueBlack(val);
                                  },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ۵. زبان برنامه
                SettingsSection(
                  title: 'زبان برنامه',
                  children: [
                    Padding(
                      padding: EdgeInsets.all(m.spaceLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'انتخاب زبان محیط کاربری',
                            style:
                                context.t.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ) ??
                                TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                          ),
                          SizedBox(height: m.spaceMd),
                          RitmoSegmentedControl<String>(
                            selected: _locale,
                            segments: const {
                              'fa': 'فارسی (پیش‌فرض)',
                              'en': 'English (آزمایشی)',
                            },
                            onSelected: (val) => _changeLocale(val),
                          ),
                          if (_locale == 'en') ...[
                            SizedBox(height: m.spaceSm),
                            Text(
                              'توجه: پشتیبانی از زبان انگلیسی در حال حاضر آزمایشی و در دست تکمیل است.',
                              style:
                                  context.t.bodySmall?.copyWith(
                                    color: colors.warning,
                                  ) ??
                                  TextStyle(color: colors.warning),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
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
    final isDark = activeBrightness == Brightness.dark;

    return Theme(
      data: RitmoTheme.build(
        palette: palette,
        brightness: activeBrightness,
        density: context.metrics.density,
      ),
      child: Builder(
        builder: (innerContext) {
          final innerColors = innerContext.colors;

          return Semantics(
            label: 'پالت ${palette.nameFa}',
            selected: isSelected,
            button: true,
            child: RitmoCard.neumorphic(
              isSelected: isSelected,
              onTap: onTap,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
              borderRadius: BorderRadius.circular(18),
              backgroundColor: innerColors.surfaceElevated,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ۱. هدر: نام پالت و نشانگر فعال بودن
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          palette.nameFa,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.w700,
                            fontFamily: 'Vazirmatn',
                            color: isSelected
                                ? innerColors.primary
                                : innerColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color.lerp(
                                  innerColors.primary,
                                  Colors.white,
                                  isDark ? 0.15 : 0.40,
                                )!,
                                innerColors.primary,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: innerColors.primary.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 11,
                            color: innerColors.onPrimary,
                          ),
                        )
                      else
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: innerColors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                    ],
                  ),

                  // ۲. کپسول ۴ رنگ اصلی پالت
                  Container(
                    height: 26,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A).withValues(alpha: 0.55)
                          : const Color(0xFFE2E8F0).withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: innerColors.primary,
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Container(color: innerColors.accent),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Container(color: innerColors.surface),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: innerColors.card,
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ۳. طیف ۸ رنگ ماژول
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(8, (i) {
                      final dotColor = innerColors.modules.bySlot(i);
                      return Container(
                        width: 6.5,
                        height: 6.5,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: dotColor.withValues(alpha: 0.3),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),

                  // ۴. شعار شخصیتی پالت
                  Text(
                    palette.taglineFa,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Vazirmatn',
                      color: innerColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

