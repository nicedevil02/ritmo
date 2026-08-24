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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                        context.t.labelSmall?.copyWith(color: colors.primary) ??
                        TextStyle(color: colors.primary),
                  ),
                ),
              ],
            ),
            SizedBox(height: m.spaceSm),
            Text(
              'این یک متن نمونه برای مشاهدهٔ تأثیر تغییرات اندازهٔ قلم و فاصله در رابط کاربری است.',
              style:
                  context.t.bodySmall?.copyWith(color: colors.textSecondary) ??
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
                      context.t.labelLarge?.copyWith(color: colors.onPrimary) ??
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

    return ValueListenableBuilder<ThemePreferences>(
      valueListenable: widget.themeRepository.preferencesNotifier,
      builder: (context, prefs, _) {
        return RitmoPageScaffold(
          padding: EdgeInsets.zero,
          appBar: const RitmoModuleAppBar(title: 'ظاهر و زبان'),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 60),
            child: Column(
              children: [
                SettingsSection(
                  title: 'اندازهٔ متن و المان‌ها',
                  children: [
                    _buildLivePreview(context, colors, prefs),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
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
                                const SizedBox(height: 4),
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
                          const SizedBox(width: 12),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
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
                          const SizedBox(height: 4),
                          Text(
                            'تنظیم فواصل، دکمه‌ها، آیکن‌ها و اهداف لمس در برنامه',
                            style:
                                context.t.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ) ??
                                TextStyle(color: colors.textSecondary),
                          ),
                          const SizedBox(height: 12),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Center(
                        child: TextButton.icon(
                          icon: const Icon(
                            CupertinoIcons.arrow_counterclockwise,
                            size: 16,
                          ),
                          label: const Text('بازگردانی به پیش‌فرض'),
                          style: TextButton.styleFrom(
                            foregroundColor: colors.textSecondary,
                            minimumSize: const Size(48, 48),
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
                      padding: const EdgeInsets.all(16),
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
                          const SizedBox(height: 12),
                          RitmoSegmentedControl<ThemeMode>(
                            segments: const {
                              ThemeMode.system: 'هماهنگ با سیستم',
                              ThemeMode.light: 'روشن',
                              ThemeMode.dark: 'تاریک',
                            },
                            selected: prefs.mode,
                            onSelected: (mode) async {
                              RitmoHapticsPolicy.selection();
                              await widget.themeRepository.updateThemeMode(mode);
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
                      padding: const EdgeInsets.all(14),
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
                          const SizedBox(height: 12),
                          ...RitmoPalette.all.map((palette) {
                            final isSelected = palette.id == prefs.paletteId;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PalettePreviewCard(
                                palette: palette,
                                isSelected: isSelected,
                                onTap: () async {
                                  final oldPalette = prefs.paletteId;
                                  final success = await widget.themeRepository.updatePalette(palette.id);
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
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'کاهش شفافیت',
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
                                const SizedBox(height: 4),
                                Text(
                                  'سطوح شیشه‌ای مات می‌شوند (مناسب دستگاه‌های ضعیف‌تر)',
                                  style:
                                      context.t.bodySmall?.copyWith(
                                        color: colors.textSecondary,
                                      ) ??
                                      TextStyle(color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          CupertinoSwitch(
                            value: prefs.reduceTransparency,
                            activeTrackColor: colors.primary,
                            onChanged: (val) {
                              RitmoHapticsPolicy.selection();
                              widget.themeRepository.updateReduceTransparency(val);
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
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
                                const SizedBox(height: 4),
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
                          const SizedBox(width: 12),
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
                      padding: const EdgeInsets.all(16),
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
                          const SizedBox(height: 12),
                          RitmoSegmentedControl<String>(
                            selected: _locale,
                            segments: const {
                              'fa': 'فارسی (پیش‌فرض)',
                              'en': 'English (آزمایشی)',
                            },
                            onSelected: (val) => _changeLocale(val),
                          ),
                          if (_locale == 'en') ...[
                            const SizedBox(height: 8),
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
                      style: innerContext.t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: innerColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'این پیش‌نمایش نحوه رندر رنگ‌های پالت را نشان می‌دهد',
                      style: innerContext.t.bodySmall?.copyWith(
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
                        style: innerContext.t.labelMedium?.copyWith(
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
