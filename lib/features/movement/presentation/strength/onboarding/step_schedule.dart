import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// گام ۴ از ۵ آنبوردینگ قدرت: زمان‌بندی، روزها و مدت هر جلسه
class StepSchedule extends StatelessWidget {
  const StepSchedule({
    super.key,
    required this.daysPerWeek,
    required this.onDaysPerWeekChanged,
    required this.preferredDays,
    required this.onPreferredDaysChanged,
    required this.sessionMinutes,
    required this.onSessionMinutesChanged,
    required this.preferredTime,
    required this.onPreferredTimeChanged,
  });

  final int daysPerWeek;
  final ValueChanged<int> onDaysPerWeekChanged;
  final List<int> preferredDays; // 1..7 (Sat=1, Sun=2, ..., Fri=7)
  final ValueChanged<List<int>> onPreferredDaysChanged;
  final int sessionMinutes;
  final ValueChanged<int> onSessionMinutesChanged;
  final String preferredTime;
  final ValueChanged<String> onPreferredTimeChanged;

  static const List<Map<String, dynamic>> _weekdays = [
    {'day': 1, 'name': 'شنبه'},
    {'day': 2, 'name': '۱شنبه'},
    {'day': 3, 'name': '۲شنبه'},
    {'day': 4, 'name': '۳شنبه'},
    {'day': 5, 'name': '۴شنبه'},
    {'day': 6, 'name': '۵شنبه'},
    {'day': 7, 'name': 'جمعه'},
  ];

  static const List<int> _durations = [20, 30, 45, 60];

  void _toggleWeekday(int day) {
    final updated = List<int>.from(preferredDays);
    if (updated.contains(day)) {
      if (updated.length > 1) {
        updated.remove(day);
      }
    } else {
      updated.add(day);
    }
    updated.sort();
    onPreferredDaysChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          MovementStrings.strengthScheduleTitle,
          style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
        ),
        const SizedBox(height: RitmoSpacing.sm),
        Text(
          'جلسات تمرینی در تقویم مرکز حرکت بر اساس این زمان‌بندی چیده می‌شوند.',
          style: RitmoTextStyles.body(colors.textSecondary),
        ),
        const SizedBox(height: RitmoSpacing.lg),

        // ۱. تعداد جلسات در هفته
        Text(
          'تعداد روزهای تمرین در هفته:',
          style: RitmoTextStyles.cardTitle(colors.textPrimary),
        ),
        const SizedBox(height: RitmoSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [2, 3, 4, 5].map((d) {
            final isSel = daysPerWeek == d;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Center(child: Text('${toPersianDigits(d)} روز')),
                  selected: isSel,
                  selectedColor: sportsColor.withValues(alpha: 0.2),
                  labelStyle: RitmoTextStyles.label(
                    isSel ? sportsColor : colors.textPrimary,
                  ),
                  onSelected: (_) => onDaysPerWeekChanged(d),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: RitmoSpacing.lg),

        // ۲. انتخاب روزهای هفته
        Text(
          'روزهای ترجیحی برای تمرین:',
          style: RitmoTextStyles.cardTitle(colors.textPrimary),
        ),
        const SizedBox(height: RitmoSpacing.xs),
        Text(
          'حداقل $daysPerWeek روز را انتخاب کنید.',
          style: RitmoTextStyles.caption(colors.textSecondary),
        ),
        const SizedBox(height: RitmoSpacing.sm),
        Wrap(
          spacing: RitmoSpacing.sm,
          runSpacing: RitmoSpacing.xs,
          children: _weekdays.map((w) {
            final isSel = preferredDays.contains(w['day']);
            return FilterChip(
              label: Text(w['name'] as String),
              selected: isSel,
              selectedColor: sportsColor.withValues(alpha: 0.2),
              checkmarkColor: sportsColor,
              labelStyle: RitmoTextStyles.label(
                isSel ? sportsColor : colors.textSecondary,
              ),
              onSelected: (_) => _toggleWeekday(w['day'] as int),
            );
          }).toList(),
        ),

        const SizedBox(height: RitmoSpacing.lg),

        // ۳. مدت هر جلسه
        Text(
          'مدت زمان هر جلسه:',
          style: RitmoTextStyles.cardTitle(colors.textPrimary),
        ),
        const SizedBox(height: RitmoSpacing.sm),
        Row(
          children: _durations.map((dur) {
            final isSel = sessionMinutes == dur;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Center(child: Text('${toPersianDigits(dur)} دقیقه')),
                  selected: isSel,
                  selectedColor: sportsColor.withValues(alpha: 0.2),
                  labelStyle: RitmoTextStyles.label(
                    isSel ? sportsColor : colors.textPrimary,
                  ),
                  onSelected: (_) => onSessionMinutesChanged(dur),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
