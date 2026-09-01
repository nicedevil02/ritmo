import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';
import 'package:ritmo/features/calendar/presentation/logic/morning_brief.dart';

class CalendarManagementSheet extends StatefulWidget {
  const CalendarManagementSheet({
    super.key,
    required this.selectedDate,
    required this.currentScale,
    required this.healthIssueCount,
    required this.onSelectScale,
    required this.onOpenDayReview,
    required this.onOpenDayMarkPicker,
    required this.onOpenAllPlans,
    required this.onRefresh,
    this.onSaveDayTemplate,
    this.onApplyDayTemplate,
  });

  final DateTime selectedDate;
  final JourneyScale currentScale;
  final int healthIssueCount;
  final ValueChanged<JourneyScale> onSelectScale;
  final VoidCallback onOpenDayReview;
  final VoidCallback onOpenDayMarkPicker;
  final VoidCallback onOpenAllPlans;
  final VoidCallback onRefresh;
  final VoidCallback? onSaveDayTemplate;
  final VoidCallback? onApplyDayTemplate;

  static Future<void> show({
    required BuildContext context,
    required DateTime selectedDate,
    required JourneyScale currentScale,
    required int healthIssueCount,
    required ValueChanged<JourneyScale> onSelectScale,
    required VoidCallback onOpenDayReview,
    required VoidCallback onOpenDayMarkPicker,
    required VoidCallback onOpenAllPlans,
    required VoidCallback onRefresh,
    VoidCallback? onSaveDayTemplate,
    VoidCallback? onApplyDayTemplate,
  }) {
    RitmoHaptics.sheetOpen();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.60,
        minChildSize: 0.40,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.60],
        expand: false,
        builder: (context, scrollController) => CalendarManagementSheet(
          selectedDate: selectedDate,
          currentScale: currentScale,
          healthIssueCount: healthIssueCount,
          onSelectScale: onSelectScale,
          onOpenDayReview: onOpenDayReview,
          onOpenDayMarkPicker: onOpenDayMarkPicker,
          onOpenAllPlans: onOpenAllPlans,
          onRefresh: onRefresh,
          onSaveDayTemplate: onSaveDayTemplate,
          onApplyDayTemplate: onApplyDayTemplate,
        ),
      ),
    ).then((result) {
      RitmoHaptics.sheetClose();
      return result;
    });
  }

  @override
  State<CalendarManagementSheet> createState() =>
      _CalendarManagementSheetState();
}

class _CalendarManagementSheetState extends State<CalendarManagementSheet> {
  bool _compressRecurring = false;
  bool _showHijri = false;

  @override
  void initState() {
    super.initState();
    _compressRecurring = SettingsService.instance.get<bool>(
      'calendar_compress_recurring',
    );
    _showHijri = SettingsService.instance.get<bool>('calendar_show_hijri');
  }

  Future<void> _toggleCompress(bool value) async {
    setState(() => _compressRecurring = value);
    await SettingsService.instance.set('calendar_compress_recurring', value);
    widget.onRefresh();
  }

  Future<void> _toggleHijri(bool value) async {
    setState(() => _showHijri = value);
    await SettingsService.instance.set('calendar_show_hijri', value);
    widget.onRefresh();
  }

  Future<void> _showMorningBrief() async {
    Navigator.of(context).pop();
    final text = await MorningBrief.generateText(date: widget.selectedDate);
    if (!mounted) return;
    unawaited(
      RitmoDialog.show(
        context,
        title: 'خلاصه صبحگاهی',
        content: text,
        confirmLabel: 'متوجه شدم',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    const sheetRadius = BorderRadius.vertical(
      top: Radius.circular(RitmoRadius.sheet),
    );

    final content = SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle Bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(
                top: RitmoSpacing.md,
                bottom: RitmoSpacing.sm,
              ),
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: colors.textPrimary.withValues(alpha: isDark ? 0.18 : 0.22),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Title Row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: RitmoSpacing.lg,
              vertical: RitmoSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, size: 20, color: colors.primary),
                const SizedBox(width: RitmoSpacing.sm),
                Expanded(
                  child: Text(
                    'مدیریت تقویم',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            thickness: 0.5,
            color: colors.divider,
          ),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                RitmoSpacing.lg,
                RitmoSpacing.md,
                RitmoSpacing.lg,
                RitmoSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: Display / نماها
                  _buildSectionHeader('نمایش و نماها', colors),
                  const SizedBox(height: RitmoSpacing.xs),
                  _buildActionTile(
                    icon: Icons.view_week_outlined,
                    title: 'نمای هفته',
                    subtitle: 'بررسی کل هفته در یک نگاه',
                    isSelected: widget.currentScale == JourneyScale.week,
                    colors: colors,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelectScale(JourneyScale.week);
                    },
                  ),
                  _buildActionTile(
                    icon: Icons.calendar_view_month_outlined,
                    title: 'نمای سال',
                    subtitle: 'بررسی ۱۲ ماه سال و نقشه حرارتی',
                    isSelected: widget.currentScale == JourneyScale.year,
                    colors: colors,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelectScale(JourneyScale.year);
                    },
                  ),
                  _buildSwitchTile(
                    icon: Icons.unfold_less_rounded,
                    title: 'فشرده‌سازی تکرارها',
                    subtitle: 'تجمیع روتین‌های روزانه تکراری',
                    value: _compressRecurring,
                    colors: colors,
                    onChanged: _toggleCompress,
                  ),
                  _buildSwitchTile(
                    icon: Icons.nightlight_round,
                    title: 'نمایش گاهشمار قمری',
                    subtitle: 'نمایش مناسبت‌ها و روزهای قمری',
                    value: _showHijri,
                    colors: colors,
                    onChanged: _toggleHijri,
                  ),

                  const SizedBox(height: RitmoSpacing.lg),

                  // Section 2: Day Actions / روز
                  _buildSectionHeader('روز', colors),
                  const SizedBox(height: RitmoSpacing.xs),
                  _buildActionTile(
                    icon: Icons.auto_stories_outlined,
                    title: 'روز من (مرور و خلاصه)',
                    subtitle: 'بررسی عملکرد، امتیازها و کارهای انجام‌شده',
                    colors: colors,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onOpenDayReview();
                    },
                  ),
                  _buildActionTile(
                    icon: Icons.flag_outlined,
                    title: 'نشان روز',
                    subtitle:
                        'تعیین وضعیت روز (استراحت 🌴 / سفر ✈️ / خاص ⭐)',
                    colors: colors,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onOpenDayMarkPicker();
                    },
                  ),

                  const SizedBox(height: RitmoSpacing.lg),

                  // Section 3: Tools / ابزارها
                  _buildSectionHeader('ابزارها', colors),
                  const SizedBox(height: RitmoSpacing.xs),
                  _buildActionTile(
                    icon: Icons.list_alt_rounded,
                    title: 'همهٔ برنامه‌ها',
                    subtitle: 'فهرست کامل دامنه‌ها و رجیستری',
                    badgeCount: widget.healthIssueCount,
                    colors: colors,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onOpenAllPlans();
                    },
                  ),
                  _buildActionTile(
                    icon: Icons.wb_sunny_outlined,
                    title: 'خلاصهٔ صبحگاهی',
                    subtitle: 'متن خلاصه رویدادها و اولویت‌های امروز',
                    colors: colors,
                    onTap: _showMorningBrief,
                  ),
                  if (widget.onSaveDayTemplate != null)
                    _buildActionTile(
                      icon: Icons.bookmark_add_outlined,
                      title: 'ذخیره به‌عنوان قالب روز',
                      subtitle:
                          'ذخیرهٔ چیدمان زمانی آیتم‌های این روز برای استفادهٔ مجدد',
                      colors: colors,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onSaveDayTemplate!();
                      },
                    ),
                  if (widget.onApplyDayTemplate != null)
                    _buildActionTile(
                      icon: Icons.dashboard_customize_outlined,
                      title: 'اعمال قالب روز',
                      subtitle:
                          'بارگذاری و چینش زمان‌بندی از روی قالب‌های ذخیره‌شده',
                      colors: colors,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onApplyDayTemplate!();
                      },
                    ),

                  const SizedBox(height: RitmoSpacing.md),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final sheetBody = Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        type: MaterialType.transparency,
        child: content,
      ),
    );

    Widget containerWidget;
    if (!isGlass) {
      containerWidget = Container(
        constraints: BoxConstraints(
          maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.9),
        ),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: sheetRadius,
          border: Border.all(
            color: isDark ? colors.border : colors.divider,
            width: 1.0,
          ),
        ),
        child: sheetBody,
      );
    } else {
      containerWidget = Container(
        constraints: BoxConstraints(
          maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.9),
        ),
        child: ClipRRect(
          borderRadius: sheetRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.glassTint,
                borderRadius: sheetRadius,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.white.withValues(alpha: 0.70),
                  width: 1.0,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: sheetRadius,
                  gradient: isDark
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.14),
                            Colors.white.withValues(alpha: 0.04),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.03, 0.45],
                        )
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.75),
                            Colors.white.withValues(alpha: 0.20),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.03, 0.45],
                        ),
                ),
                child: sheetBody,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: containerWidget,
    );
  }

  Widget _buildSectionHeader(String title, RitmoColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: colors.textSecondary.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required RitmoColors colors,
    required VoidCallback onTap,
    bool isSelected = false,
    int badgeCount = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RitmoSpacing.xs),
      child: InkWell(
        onTap: () {
          RitmoHaptics.selection();
          onTap();
        },
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.12)
                : colors.card.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(RitmoRadius.card),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : colors.border.withValues(alpha: 0.25),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? colors.primary.withValues(alpha: 0.2)
                      : colors.surface,
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: isSelected ? colors.primary : colors.textPrimary,
                ),
              ),
              const SizedBox(width: RitmoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: isSelected ? colors.primary : colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  ),
                  child: Text(
                    toPersianDigits(badgeCount.toString()),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 14,
                color: colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required RitmoColors colors,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RitmoSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(color: colors.border.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surface,
              ),
              child: Icon(icon, size: 19, color: colors.textPrimary),
            ),
            const SizedBox(width: RitmoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeTrackColor: colors.primary,
              onChanged: (val) {
                RitmoHaptics.selection();
                onChanged(val);
              },
            ),
          ],
        ),
      ),
    );
  }
}
