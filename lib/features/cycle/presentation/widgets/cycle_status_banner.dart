import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/models/cycle_confirmation_models.dart';

class CycleStatusBanner extends StatelessWidget {
  const CycleStatusBanner({
    super.key,
    required this.engineOutput,
    this.pendingRequest,
    required this.onOpenConfirmation,
    this.onCloseForgottenPeriod,
  });

  final CycleEngineOutput engineOutput;
  final CycleConfirmationRequest? pendingRequest;
  final VoidCallback onOpenConfirmation;
  final VoidCallback? onCloseForgottenPeriod;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ۱. بنر تأیید در انتظار
    if (pendingRequest != null) {
      final isStart =
          pendingRequest!.kind == CycleConfirmationKind.startDue ||
          pendingRequest!.kind == CycleConfirmationKind.startOverdue;

      final title = isStart
          ? 'بازبینی موعد ریتم بدنی'
          : 'بررسی وضعیت پایان دوره';
      final subtitle = isStart
          ? 'امروز موعد تخمینی آغاز دوره است. برای تأیید یا اصلاح کلیک کنید.'
          : 'بر اساس میانگین شما، دوره پایان یافته است. برای ثبت وضعیت کلیک کنید.';

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RitmoTheme.glassCardLight(
          borderRadius: 20,
          color: colors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
          border: Border.all(
            color: colors.primary.withValues(alpha: isDark ? 0.35 : 0.25),
          ),
          child: InkWell(
            onTap: onOpenConfirmation,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.sparkles,
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_left,
                    color: colors.textSecondary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ۲. بنر دورهٔ طولانی‌تر از میانگین (بدون تأیید مسدودکننده)
    if (engineOutput.isOpenPeriodBeyondAverage &&
        engineOutput.isBleedingConfirmed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RitmoTheme.glassCardLight(
          borderRadius: 20,
          color: colors.warning.withValues(alpha: isDark ? 0.15 : 0.08),
          border: Border.all(
            color: colors.warning.withValues(alpha: isDark ? 0.35 : 0.25),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: colors.warning,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'دورهٔ جاری بیش از میانگین شما طول کشیده است',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'روز ${PersianDigits.toFa(engineOutput.dayOfPeriod.toString())} خونریزی در حال ثبت است.',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onCloseForgottenPeriod != null)
                  TextButton(
                    onPressed: onCloseForgottenPeriod,
                    child: Text(
                      'ثبت پایان',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // ۳. تأخیر در شروع دوره
    if (engineOutput.isOverdue && engineOutput.daysOverdue > 0) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RitmoTheme.glassCardLight(
          borderRadius: 20,
          color: colors.accent.withValues(alpha: isDark ? 0.15 : 0.08),
          border: Border.all(
            color: colors.accent.withValues(alpha: isDark ? 0.35 : 0.25),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(CupertinoIcons.clock_fill, color: colors.accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تأخیر در موعد ریتم بدنی',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${PersianDigits.toFa(engineOutput.daysOverdue.toString())} روز از موعد تخمینی گذشته است.',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
