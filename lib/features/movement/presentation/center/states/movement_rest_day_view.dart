import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/week_rail.dart';

/// وضعیت B صفحهٔ اصلی: روز استراحت برنامه‌ریزی‌شده (P-08 State B)
class MovementRestDayView extends StatelessWidget {
  const MovementRestDayView({
    super.key,
    required this.railDays,
    required this.onConfirmRestDay,
    required this.onOpenPicker,
    required this.onSelectDay,
  });

  final List<MovementDayData> railDays;
  final VoidCallback onConfirmRestDay;
  final VoidCallback onOpenPicker;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WeekRail(
          days: railDays,
          onDaySelected: onSelectDay,
        ),
        const SizedBox(height: RitmoSpacing.xl),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // آیکون و پیام آرامش‌بخش ریکاوری
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: sportsColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.spa_rounded,
                      size: 38,
                      color: sportsColor,
                    ),
                  ),
                ),
                const SizedBox(height: RitmoSpacing.lg),

                Text(
                  'امروز استراحت کردن خودش تمرینه.',
                  style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: RitmoSpacing.sm),

                Text(
                  'بدن در زمان استراحت بازسازی می‌شود و برای جلسهٔ بعدی قوی‌تر می‌گردد.',
                  style: RitmoTextStyles.body(colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: RitmoSpacing.xxl),

                // دکمهٔ «همین‌طور ثبتش کن»
                ElevatedButton(
                  onPressed: onConfirmRestDay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.surfaceElevated,
                    foregroundColor: colors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                      side: BorderSide(color: colors.borderSubtle),
                    ),
                  ),
                  child: const Text('همین‌طور ثبتش کن (استراحت)'),
                ),
                const SizedBox(height: RitmoSpacing.md),

                // دکمهٔ «بازم می‌خوام تمرین کنم»
                TextButton.icon(
                  onPressed: onOpenPicker,
                  icon: Icon(Icons.add_rounded, color: sportsColor),
                  label: Text(
                    'بازم می‌خوام تمرین کنم',
                    style: RitmoTextStyles.body(sportsColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
