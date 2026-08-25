import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_preferences.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_segmented_control.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
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
                          ...RitmoPalette.all.map((palette) {
                            final isSelected = palette.id == prefs.paletteId;
                            return Padding(
                              padding: EdgeInsets.only(bottom: m.spaceMd),
                              child: _PalettePreviewCard(
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
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),

                // ۴. جلوه‌های بصری و نمایشگر
                SettingsSection(
                  title: 'جلوه‌های بصری و نمایشگر',
                  children: [
                    // ۱. خاموش‌سازی کامل متریال شیشه‌ای
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
                                  'غیرفعال‌سازی متریال شیشه‌ای',
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
                                  'حذف افکت بلور شیشه‌ای برای روان‌تر شدن برنامه در گوشی‌های ضعیف‌تر',
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
                            value: prefs.reduceTransparency,
                            activeTrackColor: colors.primary,
                            onChanged: (val) {
                              RitmoHapticsPolicy.selection();
                              widget.themeRepository.updateReduceTransparency(
                                val,
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    if (!prefs.reduceTransparency) ...[
                      // پیش‌نمایش زنده متریال شیشه‌ای
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: m.spaceLg,
                          vertical: m.spaceSm,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(RitmoRadius.card),
                          child: Stack(
                            children: [
                              // پس‌زمینه رنگی پیش‌نمایش
                              Container(
                                height: 84,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colors.primary.withValues(alpha: 0.6),
                                      colors.accent.withValues(alpha: 0.5),
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'پیش‌نمایش زنده متریال شیشه‌ای ریتمو',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      fontFamily: 'Vazirmatn',
                                    ),
                                  ),
                                ),
                              ),
                              // لایه شیشه روی آن
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: RitmoGlassCard(
                                    borderRadius: BorderRadius.circular(12),
                                    blurSigma: prefs.glassBlurSigma,
                                    color: (context.isDark ? Colors.black : Colors.white).withValues(
                                      alpha: (prefs.glassOpacityPercent / 100.0).clamp(0.05, 0.95),
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.auto_awesome,
                                            size: 18,
                                            color: colors.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'ماتی: ${prefs.glassBlurSigma.round()}px | شفافیت: ${prefs.glassOpacityPercent}٪',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: colors.textPrimary,
                                              fontFamily: 'Vazirmatn',
                                            ),
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

    return Theme(
      data: RitmoTheme.build(
        palette: palette,
        brightness: activeBrightness,
        density: context.metrics.density,
      ),
      child: Builder(
        builder: (innerContext) {
          final innerColors = innerContext.colors;
          final innerMetrics = innerContext.metrics;

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
                padding: EdgeInsets.all(innerMetrics.spaceLg),
                decoration: BoxDecoration(
                  color: innerColors.surface,
                  borderRadius: BorderRadius.circular(innerMetrics.radiusCard),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with name and radio
                    Row(
                      children: [
                        Wrap(
                          spacing: innerMetrics.spaceXs,
                          runSpacing: innerMetrics.spaceXs,
                          children: [
                            _ColorDot(color: innerColors.primary),
                            _ColorDot(color: innerColors.accent),
                            _ColorDot(color: innerColors.surface),
                            _ColorDot(color: innerColors.card),
                          ],
                        ),
                        SizedBox(width: innerMetrics.spaceSm),
                        Expanded(
                          child: Text(
                            palette.nameFa,
                            style: innerContext.t.titleMedium?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isSelected
                                  ? innerColors.primary
                                  : innerColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: EdgeInsets.all(innerMetrics.spaceXs),
                            decoration: BoxDecoration(
                              color: innerColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: innerMetrics.iconSm,
                              color: innerColors.onPrimary,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: innerMetrics.spaceMd),

                    // Sample Title & Subtitle
                    Text(
                      'نمونه عنوان کارت',
                      style: innerContext.t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: innerColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: innerMetrics.spaceXs),
                    Text(
                      'این پیش‌نمایش نحوه رندر رنگ‌های پالت را نشان می‌دهد',
                      style: innerContext.t.bodySmall?.copyWith(
                        color: innerColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: innerMetrics.spaceMd),

                    // Sample button
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: innerMetrics.spaceMd,
                        vertical: innerMetrics.spaceSm,
                      ),
                      decoration: BoxDecoration(
                        color: innerColors.primary,
                        borderRadius: BorderRadius.circular(
                          innerMetrics.radiusField,
                        ),
                      ),
                      child: Text(
                        'دکمه نمونه',
                        style: innerContext.t.labelMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: innerColors.onPrimary,
                        ),
                      ),
                    ),
                    SizedBox(height: innerMetrics.spaceMd),

                    // 8 Module color circles
                    Row(
                      children: List.generate(8, (i) {
                        final dotSize = (10.0 * innerMetrics.densityFactor)
                            .roundToDouble();
                        return Padding(
                          padding: EdgeInsetsDirectional.only(
                            end: innerMetrics.spaceXs,
                          ),
                          child: Container(
                            width: dotSize,
                            height: dotSize,
                            decoration: BoxDecoration(
                              color: innerColors.modules.bySlot(i),
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: innerMetrics.spaceMd),

                    // Name & Tagline
                    Text(
                      '${palette.nameFa} · ${palette.taglineFa}',
                      style: innerContext.t.labelLarge?.copyWith(
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
    final dotSize = (14.0 * context.metrics.densityFactor).roundToDouble();
    return Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: context.colors.border.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
    );
  }
}
