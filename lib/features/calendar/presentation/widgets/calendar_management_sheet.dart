import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_sheet_scaffold.dart';
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
  });

  final DateTime selectedDate;
  final JourneyScale currentScale;
  final int healthIssueCount;
  final ValueChanged<JourneyScale> onSelectScale;
  final VoidCallback onOpenDayReview;
  final VoidCallback onOpenDayMarkPicker;
  final VoidCallback onOpenAllPlans;
  final VoidCallback onRefresh;

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
  }) {
    return RitmoSheetScaffold.present<void>(
      context: context,
      semanticsLabel: 'مدیریت و تنظیمات تقویم',
      builder: (context) => CalendarManagementSheet(
        selectedDate: selectedDate,
        currentScale: currentScale,
        healthIssueCount: healthIssueCount,
        onSelectScale: onSelectScale,
        onOpenDayReview: onOpenDayReview,
        onOpenDayMarkPicker: onOpenDayMarkPicker,
        onOpenAllPlans: onOpenAllPlans,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  State<CalendarManagementSheet> createState() => _CalendarManagementSheetState();
}

class _CalendarManagementSheetState extends State<CalendarManagementSheet> {
  bool _compressRecurring = false;
  bool _showHijri = false;

  @override
  void initState() {
    super.initState();
    _compressRecurring = SettingsService.instance.get<bool>('calendar_compress_recurring');
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
    unawaited(showDialog<void>(
      context: context,
      builder: (ctx) {
        final colors = ctx.colors;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.wb_sunny_outlined, color: colors.primary),
              const SizedBox(width: RitmoSpacing.sm),
              const Text('خلاصه صبحگاهی'),
            ],
          ),
          content: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: colors.textPrimary,
              height: 1.6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('متوجه شدم'),
            ),
          ],
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.lg,
          vertical: RitmoSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: RitmoSpacing.md),

            // Title
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 20, color: colors.primary),
                const SizedBox(width: RitmoSpacing.sm),
                Text(
                  'مدیریت تقویم',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: RitmoSpacing.lg),

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
              subtitle: 'تعیین وضعیت روز (استراحت 🌴 / سفر ✈️ / خاص ⭐)',
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

            const SizedBox(height: RitmoSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, RitmoColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: colors.textSecondary,
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
    return InkWell(
      onTap: () {
        RitmoHapticsPolicy.selection();
        onTap();
      },
      borderRadius: BorderRadius.circular(RitmoRadius.card),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.10) : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(
            color: isSelected ? colors.primary : colors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? colors.primary : colors.textPrimary),
            const SizedBox(width: RitmoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? colors.primary : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.error,
                  borderRadius: BorderRadius.circular(RitmoRadius.badge),
                ),
                child: Text(
                  toPersianDigits(badgeCount),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colors.onPrimary,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_left_rounded, size: 18, color: colors.textTertiary),
          ],
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.textPrimary),
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
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: colors.primary,
            onChanged: (val) {
              RitmoHapticsPolicy.tap();
              onChanged(val);
            },
          ),
        ],
      ),
    );
  }
}
