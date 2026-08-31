import 'package:flutter/cupertino.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
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
      title: 'ورق روز — ',
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ۱. بخش خواب
        RitmoCard.neumorphic(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.sleepAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.moon_stars_fill, color: colors.sleepAccent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'خواب شبانه',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day.sleepHours != null
                          ? 'خواب: '
                          : 'خواب ثبت نشده است',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              RitmoNeuButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                onTap: () {
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
                  day.sleepHours != null ? 'ویرایش' : 'ثبت',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ۲. بخش انرژی
        RitmoCard.neumorphic(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.energyAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.bolt_fill, color: colors.energyAccent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سطح انرژی روزانه',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day.energyLevel != null
                          ? 'انرژی: ٪'
                          : 'انرژی ثبت نشده است',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              RitmoNeuButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                onTap: () {
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
                  day.energyLevel != null ? 'ویرایش' : 'ثبت',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ۳. بخش حال روحی
        RitmoCard.neumorphic(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.reflectionAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.heart_fill, color: colors.reflectionAccent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حال و رضایت درونی',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day.moodScore != null
                          ? 'حال:  از ۵'
                          : 'حال ثبت نشده است',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (moodNote != null && moodNote!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        moodNote!,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ۴. بخش بازتاب
        RitmoCard.neumorphic(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.pencil_ellipsis_rectangle, color: colors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تأمل و بازتاب شبانه',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day.hasReflection
                          ? 'بازتاب ثبت شده است ✅'
                          : 'بازتاب ثبت نشده است',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              RitmoNeuButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                onTap: () {
                  Navigator.pop(context);
                  DailyReflectionSheet.show(
                    context: context,
                    date: day.dateStr,
                    onSaved: onLogChanged,
                  );
                },
                child: Text(
                  day.hasReflection ? 'ویرایش' : 'ثبت بازتاب',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
