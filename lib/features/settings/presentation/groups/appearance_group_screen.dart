import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_preferences.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_segmented_control.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/features/profile/presentation/theme_settings_screen.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_section.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_tile.dart';

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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: EdgeInsets.all(m.spaceMd),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(m.radiusCard),
        border: Border.all(color: colors.border.withValues(alpha: 0.15)),
      ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final showAdvanced = SettingsService.instance.get<bool>(
      'show_advanced_settings',
    );

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
                              value: prefs.textScalePercent.toDouble(),
                              min: 85,
                              max: 140,
                              divisions: 5,
                              activeColor: colors.primary,
                              onChanged: (val) {
                                final stepped = RitmoUiScale.percentFromFactor(
                                  RitmoUiScale.factorFromPercent(val.round()),
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
                SettingsSection(
                  title: 'پوسته و تم',
                  children: [
                    SettingsTile(
                      title: 'تنظیمات تم و پالت رنگی',
                      subtitle: 'انتخاب حالت روشنایی و پالت‌های رنگی اختصاصی',
                      leading: Icon(
                        CupertinoIcons.paintbrush_fill,
                        color: colors.primary,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => ThemeSettingsScreen(
                              themeRepository: widget.themeRepository,
                            ),
                          ),
                        );
                      },
                    ),
                    if (showAdvanced) ...[
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
                              onChanged: (val) => widget.themeRepository
                                  .updateReduceTransparency(val),
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
                                          color: colors.textPrimary,
                                        ) ??
                                        TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: colors.textPrimary,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'پس‌زمینه کاملاً مشکی در حالت تاریک جهت صرفه‌جویی در باتری',
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
                              onChanged: (val) =>
                                  widget.themeRepository.updateTrueBlack(val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
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
