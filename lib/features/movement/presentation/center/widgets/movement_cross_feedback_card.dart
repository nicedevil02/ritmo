import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// کارت بازخورد چندماژولهٔ سبک و بدون سرزنش (P-24 — حداکثر یک کارت)
class MovementCrossFeedbackCard extends StatelessWidget {
  const MovementCrossFeedbackCard({
    super.key,
    this.sleepHours,
    this.moodScore,
  });

  final double? sleepHours;
  final int? moodScore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    // ۱. اولویت اول: کمبود خواب (< ۶ ساعت)
    if (sleepHours != null && sleepHours! < 6.0) {
      return Container(
        margin: const EdgeInsets.only(bottom: RitmoSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.md,
          vertical: RitmoSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(Icons.bedtime_outlined, size: 18, color: sportsColor),
            const SizedBox(width: RitmoSpacing.sm),
            Expanded(
              child: Text(
                'امروز خوابت کم بوده. پیاده‌روی سبک پیشنهاد می‌شه.',
                style: RitmoTextStyles.caption(colors.textPrimary),
              ),
            ),
          ],
        ),
      );
    }

    // ۲. اولویت دوم: خلق پایین (< ۳ از ۵)
    if (moodScore != null && moodScore! < 3) {
      return Container(
        margin: const EdgeInsets.only(bottom: RitmoSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.md,
          vertical: RitmoSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(Icons.sentiment_neutral_outlined, size: 18, color: sportsColor),
            const SizedBox(width: RitmoSpacing.sm),
            Expanded(
              child: Text(
                'تمرین ملایم شاید حالت رو بهتر کنه.',
                style: RitmoTextStyles.caption(colors.textPrimary),
              ),
            ),
          ],
        ),
      );
    }

    // ۳. شرایط عادی -> بدون کارت
    return const SizedBox.shrink();
  }
}
