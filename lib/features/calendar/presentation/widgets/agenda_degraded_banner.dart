import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/calendar/presentation/widgets/agenda_diagnostics_sheet.dart';

/// Reusable degraded status banner for Calendar and Journey header.
///
/// Displayed when one or more agenda sources failed to load, informing the user
/// without disrupting the rest of the available agenda items.
class AgendaDegradedBanner extends StatelessWidget {
  const AgendaDegradedBanner({
    super.key,
    required this.degradedDomains,
    this.onRetry,
  });

  final Set<AgendaDomain> degradedDomains;
  final VoidCallback? onRetry;

  static String domainToPersian(AgendaDomain domain) {
    switch (domain) {
      case AgendaDomain.routine:
        return 'روتین‌ها';
      case AgendaDomain.prayer:
        return 'نمازها';
      case AgendaDomain.mustahab:
        return 'مستحبات و ادعیه';
      case AgendaDomain.worshipDebt:
        return 'قضا و دیون معنوی';
      case AgendaDomain.sport:
        return 'ورزش و تحرک';
      case AgendaDomain.medicine:
        return 'دارو و سلامت';
      case AgendaDomain.goalStep:
        return 'گام‌های هدف';
      case AgendaDomain.task:
        return 'کارهای ساده';
      case AgendaDomain.course:
        return 'دوره‌های آموزشی';
      case AgendaDomain.konkur:
        return 'درس و مطالعه';
      case AgendaDomain.cycle:
        return 'چرخهٔ زیستی';
      case AgendaDomain.event:
        return 'رویدادهای موقت';
    }
  }

  void _showDetails(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    final domainNames = degradedDomains.map(domainToPersian).toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(RitmoRadius.sheet)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(RitmoSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: colors.warning, size: 22),
                    const SizedBox(width: RitmoSpacing.sm),
                    Text(
                      'بارگذاری ناقص اطلاعات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RitmoSpacing.md),
                Text(
                  'اطلاعات بخش‌های زیر در این بازه به‌طور کامل دریافت نشد:',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: RitmoSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final name in domainNames)
                      Chip(
                        label: Text(name, style: TextStyle(fontSize: 12, color: colors.warning)),
                        backgroundColor: colors.warning.withValues(alpha: 0.12),
                        side: BorderSide(color: colors.warning.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                  ],
                ),
                const SizedBox(height: RitmoSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      AgendaDiagnosticsSheet.show(context, onRetry: onRetry);
                    },
                    icon: const Icon(Icons.bug_report_outlined, size: 18),
                    label: const Text('گزارش تشخیصی'),
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: RitmoSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onRetry!();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('تلاش مجدد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(RitmoRadius.card),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Nothing is degraded: still offer a discreet way into the diagnostics
    // report, so an unexplained empty agenda can be traced on-device.
    if (degradedDomains.isEmpty) {
      return _AgendaDiagnosticsChip(onRetry: onRetry);
    }

    final colors = context.colors;

    return Semantics(
      label: 'هشدار بارگذاری ناقص',
      button: true,
      child: GestureDetector(
        onTap: () => _showDetails(context),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(RitmoRadius.badge),
            border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: colors.warning),
              const SizedBox(width: 5),
              Text(
                'بعضی بخش‌ها کامل بارگذاری نشد',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.warning,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${toPersianDigits(degradedDomains.length)})',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colors.warning,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Discreet entry point to [AgendaDiagnosticsSheet].
class _AgendaDiagnosticsChip extends StatelessWidget {
  const _AgendaDiagnosticsChip({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      label: 'گزارش تشخیصی برنامه',
      button: true,
      child: GestureDetector(
        onTap: () => AgendaDiagnosticsSheet.show(context, onRetry: onRetry),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.textSecondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(RitmoRadius.badge),
            border: Border.all(color: colors.textSecondary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bug_report_outlined, size: 12, color: colors.textSecondary),
              const SizedBox(width: 4),
              Text(
                'چرا برنامه خالی است؟',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
