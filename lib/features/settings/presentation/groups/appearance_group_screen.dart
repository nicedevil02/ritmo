import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_preferences.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/features/settings/presentation/cards_showcase_screen.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_section.dart';

/// صفحه تنظیمات ظاهر، پوسته و زبان اپلیکیشن با طراحی مدرن بر پایه Apple HIG و نئومورفیسم ریتمو
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
  bool _hapticEnabled = true;

  @override
  void initState() {
    super.initState();
    _locale = SettingsService.instance.get<String>('locale');
    _hapticEnabled = SettingsService.instance.get<bool>('haptic_feedback_enabled');
  }

  Future<void> _changeLocale(String loc) async {
    setState(() => _locale = loc);
    await widget.localeRepository.updateLocale(Locale(loc));
  }

  Future<void> _toggleHaptic(bool enabled) async {
    setState(() => _hapticEnabled = enabled);
    await SettingsService.instance.set('haptic_feedback_enabled', enabled);
    if (enabled) {
      RitmoHapticsPolicy.selection();
    }
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
            actions: [
              IconButton(
                icon: const Icon(CupertinoIcons.square_stack_3d_up_fill),
                tooltip: 'ویترین سیستم مرجع کارت‌ها و پنجره‌ها',
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => const CardsShowcaseScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsetsDirectional.fromSTEB(
              m.spaceLg,
              m.spaceSm,
              m.spaceLg,
              m.navBarHeight + m.spaceLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── ۱. ماک‌آپ زنده یکپارچه ریتمو (Live App Hero Preview) ───
                _RitmoLiveAppPreview(
                  prefs: prefs,
                  themeRepository: widget.themeRepository,
                ),
                SizedBox(height: m.spaceLg),

                // ─── ۲. انتخاب‌گر حالت روشنایی (روشن / تاریک / خودکار) ───
                SettingsSection(
                  title: 'حالت روشنایی',
                  children: [
                    Padding(
                      padding: EdgeInsets.all(m.spaceMd),
                      child: _ThemeModeVisualSelector(
                        currentMode: prefs.mode,
                        onModeSelected: (mode) async {
                          RitmoHapticsPolicy.selection();
                          await widget.themeRepository.updateThemeMode(mode);
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: m.spaceSm),

                // ─── ۳. پالت‌های رنگی اختصاصی (Horizontal Carousel) ───
                SettingsSection(
                  title: 'پالت‌های رنگی اختصاصی',
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: m.spaceMd),
                      child: _PalettesHorizontalSelector(
                        selectedPaletteId: prefs.paletteId,
                        onPaletteSelected: (paletteId) async {
                          final oldPalette = prefs.paletteId;
                          final palette = RitmoPalette.byId(paletteId);
                          final success = await widget.themeRepository.updatePalette(paletteId);
                          if (success && context.mounted) {
                            RitmoToast.show(
                              context,
                              'پالت به «${palette.nameFa}» تغییر کرد',
                              icon: Icons.palette_rounded,
                              iconColor: palette.dark.primary,
                              onUndo: () {
                                widget.themeRepository.updatePalette(oldPalette);
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: m.spaceSm),

                // ─── ۴. اندازهٔ متن، فونت و چگالی المان‌ها ───
                SettingsSection(
                  title: 'اندازهٔ متن و المان‌ها',
                  children: [
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
                                style: context.t.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ) ??
                                    TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                              ),
                              Text(
                                '${RitmoUiScale.textLabelFor(prefs.textScalePercent)} (${toPersianDigits(prefs.textScalePercent.toString())}٪)',
                                style: context.t.bodySmall?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.bold,
                                    ) ??
                                    TextStyle(
                                      color: colors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          Semantics(
                            label: 'اندازهٔ متن',
                            value:
                                '${RitmoUiScale.textLabelFor(prefs.textScalePercent)} ${toPersianDigits(prefs.textScalePercent.toString())} درصد',
                            child: Slider(
                              value: RitmoUiScale.stepIndexFromPercent(
                                prefs.textScalePercent,
                              ).toDouble(),
                              min: 0,
                              max: (RitmoUiScale.textSteps.length - 1).toDouble(),
                              divisions: RitmoUiScale.textSteps.length - 1,
                              activeColor: colors.primary,
                              onChanged: (val) {
                                final stepped = RitmoUiScale.percentFromStepIndex(
                                  val.round(),
                                );
                                if (stepped != prefs.textScalePercent) {
                                  RitmoHapticsPolicy.selection();
                                  widget.themeRepository.updateTextScalePercent(stepped);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(color: colors.divider.withValues(alpha: 0.5), height: 1),
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
                                  style: context.t.titleSmall?.copyWith(
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
                                  'اگر روشن باشد، اندازهٔ قلم برنامه با تنظیمات بزرگنمایی گوشی همگام می‌شود.',
                                  style: context.t.bodySmall?.copyWith(
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
                              widget.themeRepository.updateFollowOsTextScale(val);
                            },
                          ),
                        ],
                      ),
                    ),
                    Divider(color: colors.divider.withValues(alpha: 0.5), height: 1),
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
                            style: context.t.titleSmall?.copyWith(
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
                            'تنظیم فواصل، دکمه‌ها، حاشیه‌ها و اهداف لمس در برنامه',
                            style: context.t.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ) ??
                                TextStyle(color: colors.textSecondary),
                          ),
                          SizedBox(height: m.spaceMd),
                          RitmoSegmentedControl<RitmoDensityLevel>(
                            selected: prefs.density,
                            segments: {
                              RitmoDensityLevel.compact: RitmoUiScale.densityLabelFor(
                                RitmoDensityLevel.compact,
                              ),
                              RitmoDensityLevel.comfortable: RitmoUiScale.densityLabelFor(
                                RitmoDensityLevel.comfortable,
                              ),
                              RitmoDensityLevel.spacious: RitmoUiScale.densityLabelFor(
                                RitmoDensityLevel.spacious,
                              ),
                              RitmoDensityLevel.xl: RitmoUiScale.densityLabelFor(
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
                SizedBox(height: m.spaceSm),

                // ─── ۵. زبان و بومی‌سازی ───
                SettingsSection(
                  title: 'زبان و منطقه',
                  children: [
                    Padding(
                      padding: EdgeInsets.all(m.spaceLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  CupertinoIcons.globe,
                                  size: 19,
                                  color: colors.primary,
                                ),
                              ),
                              SizedBox(width: m.spaceSm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'زبان محیط کاربری',
                                      style: context.t.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colors.textPrimary,
                                          ) ??
                                          TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: colors.textPrimary,
                                          ),
                                    ),
                                    Text(
                                      'انتخاب زبان منوها، اعلان‌ها و رابط برنامه',
                                      style: context.t.bodySmall?.copyWith(
                                            color: colors.textSecondary,
                                          ) ??
                                          TextStyle(color: colors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: m.spaceMd),
                          RitmoSegmentedControl<String>(
                            selected: _locale,
                            segments: const {
                              'fa': 'فارسی (پیش‌فرض)',
                              'en': 'English (Beta)',
                            },
                            onSelected: (val) => _changeLocale(val),
                          ),
                          if (_locale == 'en') ...[
                            SizedBox(height: m.spaceSm),
                            Container(
                              padding: EdgeInsets.all(m.spaceSm),
                              decoration: BoxDecoration(
                                color: colors.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(m.radiusField),
                                border: Border.all(
                                  color: colors.warning.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.exclamationmark_triangle_fill,
                                    size: 16,
                                    color: colors.warning,
                                  ),
                                  SizedBox(width: m.spaceSm),
                                  Expanded(
                                    child: Text(
                                      'پشتیبانی از زبان انگلیسی در حال حاضر آزمایشی بوده و در دست تکمیل است.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: colors.warning,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Vazirmatn',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: m.spaceSm),

                // ─── ۶. جلوه‌های پیشرفته بصری و لمسی ───
                SettingsSection(
                  title: 'جلوه‌های بصری و لمسی',
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
                                  'متریال شیشه‌ای (Liquid Glass)',
                                  style: context.t.titleSmall?.copyWith(
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
                                  'افکت بلور و شفافیت زنده در هدرها و کارت‌ها',
                                  style: context.t.bodySmall?.copyWith(
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
                              widget.themeRepository.updateReduceTransparency(!val);
                            },
                          ),
                        ],
                      ),
                    ),

                    if (!prefs.reduceTransparency) ...[
                      // اسلایدر ماتی (بلور)
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
                                  'شدت محوشدگی (بلور)',
                                  style: context.t.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ) ??
                                      TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                ),
                                Text(
                                  '${toPersianDigits(prefs.glassBlurSigma.round().toString())} پیکسل',
                                  style: TextStyle(
                                    color: colors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    fontFamily: 'Vazirmatn',
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
                                widget.themeRepository.updateGlassBlurSigma(val);
                              },
                            ),
                          ],
                        ),
                      ),

                      // اسلایدر شفافیت
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
                                  'غلظت و شفافیت سطح شیشه',
                                  style: context.t.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ) ??
                                      TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                ),
                                Text(
                                  '${toPersianDigits(prefs.glassOpacityPercent.toString())}٪',
                                  style: TextStyle(
                                    color: colors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    fontFamily: 'Vazirmatn',
                                  ),
                                ),
                              ],
                            ),
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

                      // دکمه بازگردانی مقادیر شیشه
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
                              'تنظیم مجدد شیشه به پیش‌فرض',
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

                    Divider(color: colors.divider.withValues(alpha: 0.5), height: 1),

                    // ۲. مشکی عمیق OLED
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
                                  'سیاه خالص (OLED / AMOLED)',
                                  style: context.t.titleSmall?.copyWith(
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
                                      ? 'تنها در حالت تاریک فعال است'
                                      : 'خاموش کردن پیکسل‌ها برای کاهش مصرف باتری در نمایشگرهای OLED',
                                  style: context.t.bodySmall?.copyWith(
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

                    Divider(color: colors.divider.withValues(alpha: 0.5), height: 1),

                    // ۳. بازخورد لرزشی هپتیک
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
                                  'بازخورد لمسی (هپتیک)',
                                  style: context.t.titleSmall?.copyWith(
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
                                  'ویبره و لرزش فیزیکی ملایم هنگام لمس دکمه‌ها و اسلایدرها',
                                  style: context.t.bodySmall?.copyWith(
                                        color: colors.textSecondary,
                                      ) ??
                                      TextStyle(color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: m.spaceMd),
                          CupertinoSwitch(
                            value: _hapticEnabled,
                            activeTrackColor: colors.primary,
                            onChanged: (val) => _toggleHaptic(val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: m.spaceSm),

                // ─── ۷. آزمایشگاه و سیستم مرجع کارت‌ها ───
                SettingsSection(
                  title: 'آزمایشگاه و سیستم مرجع',
                  children: [
                    Padding(
                      padding: EdgeInsets.all(m.spaceMd),
                      child: RitmoCard(
                        onTap: () {
                          RitmoHapticsPolicy.selection();
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => const CardsShowcaseScreen(),
                            ),
                          );
                        },
                        padding: EdgeInsets.all(m.spaceMd),
                        borderRadius: BorderRadius.circular(m.radiusField),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                CupertinoIcons.square_stack_3d_up_fill,
                                size: 20,
                                color: colors.primary,
                              ),
                            ),
                            SizedBox(width: m.spaceSm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ویترین سیستم مرجع کارت‌ها و پنجره‌ها',
                                    style: context.t.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: colors.textPrimary,
                                        ) ??
                                        TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: colors.textPrimary,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'مشاهده، تست استایل‌ها و فیزیک کارت‌ها و پنجره‌های ۲۴ ساعته',
                                    style: context.t.bodySmall?.copyWith(
                                          color: colors.textSecondary,
                                        ) ??
                                        TextStyle(color: colors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              CupertinoIcons.chevron_left,
                              size: 16,
                              color: colors.textTertiary,
                            ),
                          ],
                        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// کامپوننت ۱: ماک‌آپ زنده و تعاملی یکپارچه ریتمو (Live App Hero Mockup)
// ─────────────────────────────────────────────────────────────────────────────
class _RitmoLiveAppPreview extends StatefulWidget {
  final ThemePreferences prefs;
  final ThemeRepository themeRepository;

  const _RitmoLiveAppPreview({
    required this.prefs,
    required this.themeRepository,
  });

  @override
  State<_RitmoLiveAppPreview> createState() => _RitmoLiveAppPreviewState();
}

class _RitmoLiveAppPreviewState extends State<_RitmoLiveAppPreview> {
  bool _taskCompleted = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;
    final previewScale = RitmoUiScale.effectiveTextScale(
      osScale: MediaQuery.textScalerOf(context).scale(1.0),
      appPercent: widget.prefs.textScalePercent,
      followOs: widget.prefs.followOsTextScale,
    );

    final palette = RitmoPalette.byId(widget.prefs.paletteId);

    return RitmoCard(
      padding: EdgeInsets.all(m.spaceMd),
      borderRadius: BorderRadius.circular(m.radiusCard),
      variant: !widget.prefs.reduceTransparency
          ? RitmoCardVariant.glass
          : RitmoCardVariant.neumorphic,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(previewScale),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // سربرگ ماک‌آپ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        size: 15,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'پیش‌نمایش زنده محیط برنامه',
                      style: context.t.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ) ??
                          TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                            fontFamily: 'Vazirmatn',
                          ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  ),
                  child: Text(
                    palette.nameFa,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: m.spaceSm),

            // کارت نمونه روتین روزانه
            Container(
              padding: EdgeInsets.all(m.spaceSm),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(m.radiusField),
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      RitmoHapticsPolicy.selection();
                      setState(() => _taskCompleted = !_taskCompleted);
                    },
                    child: AnimatedContainer(
                      duration: RitmoMotion.state,
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _taskCompleted ? colors.success : colors.surfaceSunken,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _taskCompleted ? colors.success : colors.border,
                          width: 1.5,
                        ),
                      ),
                      child: _taskCompleted
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  SizedBox(width: m.spaceSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مدیتیشن صبحگاهی و تنفس عمیق',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _taskCompleted ? colors.textTertiary : colors.textPrimary,
                            decoration:
                                _taskCompleted ? TextDecoration.lineThrough : null,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                        Text(
                          'پالس روزانه · ۲۰ دقیقه تمرکز ذهن',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '۰۸:۳۰',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: m.spaceSm),

            // نوار نشانگر طیف رنگ ماژول‌ها
            Row(
              children: [
                Text(
                  'هارمونی ماژول‌ها: ',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: colors.textTertiary,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(8, (i) {
                      final dotColor = colors.modules.bySlot(i);
                      return Container(
                        width: 7,
                        height: 7,
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// کامپوننت ۲: انتخاب‌گر بصری حالت روشنایی (Theme Mode Visual Selector)
// ─────────────────────────────────────────────────────────────────────────────
class _ThemeModeVisualSelector extends StatelessWidget {
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onModeSelected;

  const _ThemeModeVisualSelector({
    required this.currentMode,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ThemeModeTile(
            title: 'روشن',
            subtitle: 'روز',
            icon: CupertinoIcons.sun_max_fill,
            iconColor: const Color(0xFFFF9500),
            previewGradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
            ),
            isSelected: currentMode == ThemeMode.light,
            onTap: () => onModeSelected(ThemeMode.light),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ThemeModeTile(
            title: 'تاریک',
            subtitle: 'شب',
            icon: CupertinoIcons.moon_stars_fill,
            iconColor: const Color(0xFF818CF8),
            previewGradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            ),
            isSelected: currentMode == ThemeMode.dark,
            onTap: () => onModeSelected(ThemeMode.dark),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ThemeModeTile(
            title: 'خودکار',
            subtitle: 'سیستم',
            icon: CupertinoIcons.circle_righthalf_fill,
            iconColor: const Color(0xFF06B6D4),
            previewGradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE2E8F0), Color(0xFF1E293B)],
            ),
            isSelected: currentMode == ThemeMode.system,
            onTap: () => onModeSelected(ThemeMode.system),
          ),
        ),
      ],
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Gradient previewGradient;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeModeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.previewGradient,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      label: 'حالت $title',
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: RitmoMotion.state,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? colors.primary : colors.border.withValues(alpha: 0.5),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // کارت گرافیکی مینیاتوری حالت
              Container(
                height: 52,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: previewGradient,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? colors.primary : colors.textPrimary,
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: colors.primary,
                    ),
                  ],
                ],
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: colors.textSecondary,
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// کامپوننت ۳: کاروسل افقی پالت‌های رنگی (Palettes Horizontal Selector)
// ─────────────────────────────────────────────────────────────────────────────
class _PalettesHorizontalSelector extends StatelessWidget {
  final RitmoPaletteId selectedPaletteId;
  final ValueChanged<RitmoPaletteId> onPaletteSelected;

  const _PalettesHorizontalSelector({
    required this.selectedPaletteId,
    required this.onPaletteSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 154,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: RitmoPalette.all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final palette = RitmoPalette.all[index];
          final isSelected = palette.id == selectedPaletteId;

          return SizedBox(
            width: 170,
            child: _PaletteCard(
              palette: palette,
              isSelected: isSelected,
              onTap: () => onPaletteSelected(palette.id),
            ),
          );
        },
      ),
    );
  }
}

class _PaletteCard extends StatelessWidget {
  final RitmoPalette palette;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaletteCard({
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

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
            child: GestureDetector(
              onTap: () {
                RitmoHapticsPolicy.selection();
                onTap();
              },
              child: AnimatedContainer(
                duration: RitmoMotion.state,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: innerColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? innerColors.primary
                        : innerColors.border.withValues(alpha: 0.5),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: innerColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // هدر: نام پالت و نشان انتخاب
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            palette.nameFa,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                              color: isSelected ? innerColors.primary : innerColors.textPrimary,
                              fontFamily: 'Vazirmatn',
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
                              color: innerColors.primary,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 11,
                              color: innerColors.onPrimary,
                            ),
                          )
                        else
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: innerColors.primary.withValues(alpha: 0.35),
                            ),
                          ),
                      ],
                    ),

                    // کپسول ۴ رنگ اصلی
                    Container(
                      height: 22,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A).withValues(alpha: 0.5)
                            : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
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
                          const SizedBox(width: 1.5),
                          Expanded(child: Container(color: innerColors.accent)),
                          const SizedBox(width: 1.5),
                          Expanded(child: Container(color: innerColors.surface)),
                          const SizedBox(width: 1.5),
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

                    // طیف ۸ رنگ ماژول‌ها
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(8, (i) {
                        final dotColor = innerColors.modules.bySlot(i);
                        return Container(
                          width: 5.5,
                          height: 5.5,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),

                    // شعار پالت
                    Text(
                      palette.taglineFa,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: innerColors.textSecondary,
                        fontFamily: 'Vazirmatn',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
