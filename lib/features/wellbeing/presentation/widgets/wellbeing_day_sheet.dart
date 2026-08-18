import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/core/widgets/ritmo_sheet_scaffold.dart';
import 'package:ritmo/features/energy/presentation/widgets/quick_log_sheet.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';
import 'package:ritmo/features/sleep/presentation/widgets/sleep_log_sheet.dart';
import 'package:ritmo/features/today/presentation/widgets/daily_reflection_sheet.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/wellbeing_pulse_chart.dart';

/// ورق یکپارچهٔ جزئیات و ثبت اطلاعات یک روز
class WellbeingDaySheet extends StatelessWidget {
  const WellbeingDaySheet({
    super.key,
    required this.day,
    this.sleepTarget,
    this.onLogChanged,
    this.moodNote,
  });

  final WellbeingPulseDayData day;
  final SleepTarget? sleepTarget;
  final VoidCallback? onLogChanged;
  final String? moodNote;

  static Future<void> show({
    required BuildContext context,
    required WellbeingPulseDayData day,
    SleepTarget? sleepTarget,
    VoidCallback? onLogChanged,
    String? moodNote,
  }) {
    RitmoHapticsPolicy.tap();
    return RitmoSheetScaffold.present(
      context: context,
      title: 'ورق روز — ${RitmoNumber.fa(day.dateStr)}',
      builder: (ctx) => WellbeingDaySheet(
        day: day,
        sleepTarget: sleepTarget,
        onLogChanged: onLogChanged,
        moodNote: moodNote,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // بخش خواب
          ListTile(
            leading: Icon(Icons.bedtime, color: colors.sleepAccent),
            title: Text(
              day.sleepHours != null
                  ? 'خواب: ${RitmoNumber.faHours(day.sleepHours!)}'
                  : 'خواب ثبت نشده است',
              style: RitmoTextStyles.body(colors.textPrimary),
            ),
            trailing: TextButton(
              onPressed: () {
                Navigator.pop(context);
                RitmoSheetScaffold.present(
                  context: context,
                  title: 'ثبت خواب',
                  builder: (_) => SleepLogSheet(
                    onSaved: () {
                      onLogChanged?.call();
                    },
                    target: sleepTarget ?? SleepTarget.defaultTarget(),
                  ),
                );
              },
              child: Text(
                'ثبت / ویرایش',
                style: RitmoTextStyles.label(colors.primary),
              ),
            ),
          ),
          const Divider(height: 1),

          // بخش انرژی
          ListTile(
            leading: Icon(Icons.bolt, color: colors.energyAccent),
            title: Text(
              day.energyLevel != null
                  ? 'انرژی: ${RitmoNumber.faInt((day.energyLevel! * 33.33).round().clamp(0, 100))}٪'
                  : 'انرژی ثبت نشده است',
              style: RitmoTextStyles.body(colors.textPrimary),
            ),
            trailing: TextButton(
              onPressed: () {
                Navigator.pop(context);
                RitmoSheetScaffold.present(
                  context: context,
                  title: 'ثبت انرژی',
                  builder: (_) => QuickLogSheet(
                    onSaved: () {
                      onLogChanged?.call();
                    },
                  ),
                );
              },
              child: Text(
                'ثبت / ویرایش',
                style: RitmoTextStyles.label(colors.primary),
              ),
            ),
          ),
          const Divider(height: 1),

          // بخش حال
          ListTile(
            leading: Icon(
              Icons.sentiment_satisfied_alt,
              color: colors.reflectionAccent,
            ),
            title: Text(
              day.moodScore != null
                  ? 'حال: ${RitmoNumber.fa(day.moodScore!.toStringAsFixed(1))} از ۵'
                  : 'حال ثبت نشده است',
              style: RitmoTextStyles.body(colors.textPrimary),
            ),
            subtitle: (moodNote != null && moodNote!.isNotEmpty)
                ? Text(
                    moodNote!,
                    style: RitmoTextStyles.caption(colors.textSecondary),
                  )
                : null,
          ),
          const Divider(height: 1),

          // بخش بازتاب
          ListTile(
            leading: Icon(Icons.edit_note, color: colors.primary),
            title: Text(
              day.hasReflection
                  ? 'بازتاب ثبت شده است ✅'
                  : 'بازتاب ثبت نشده است',
              style: RitmoTextStyles.body(colors.textPrimary),
            ),
            trailing: TextButton(
              onPressed: () {
                Navigator.pop(context);
                DailyReflectionSheet.show(
                  context: context,
                  date: day.dateStr,
                  onSaved: onLogChanged,
                );
              },
              child: Text(
                'ثبت بازتاب',
                style: RitmoTextStyles.label(colors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
