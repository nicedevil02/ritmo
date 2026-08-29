import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/dashboard_module_summary.dart';

/// فهرست سیستم‌های فعال متصل به سامانه مرجع کارت‌های نئومورفیک ریتمو.
class ModuleSummaryGrid extends StatelessWidget {
  const ModuleSummaryGrid({
    super.key,
    required this.summaries,
    required this.onModuleTap,
  });

  final List<DashboardModuleSummary> summaries;
  final void Function(String moduleId) onModuleTap;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;

    return RitmoCard.neumorphic(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── هدر مرجع کارت نئومورفیک ──
          RitmoCardHeader(
            title: 'سیستم‌های فعال',
            subtitle: 'وضعیت لحظه‌ای و دسترسی سریع به سامانه‌ها',
            icon: CupertinoIcons.square_grid_2x2_fill,
            iconColor: colors.primary,
          ),
          const SizedBox(height: 4),
          const RitmoCardDivider(),
          const SizedBox(height: 6),

          // ── لیست ردیف‌های تعاملی سیستم‌ها ──
          for (int i = 0; i < summaries.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Divider(
                  height: 1,
                  thickness: 0.6,
                  color: colors.border.withValues(alpha: 0.35),
                  indent: 48,
                ),
              ),
            _ModuleListRow(
              summary: summaries[i],
              onTap: () => onModuleTap(summaries[i].moduleId),
            ),
          ],
        ],
      ),
    );
  }
}

/// ردیف فهرستی سیستم‌های فعال با آیکون فرورفته، نام سیستم، وضعیت و مقدار اصلی.
class _ModuleListRow extends StatelessWidget {
  const _ModuleListRow({
    required this.summary,
    required this.onTap,
  });

  final DashboardModuleSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: '${summary.title}: ${summary.primary}، ${summary.secondary}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            RitmoHaptics.selection();
            onTap();
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                // شیار فرورفته نئومورفیک آیکون
                RitmoNeuSurface(
                  height: 38,
                  width: 38,
                  radius: 12,
                  sunken: true,
                  padding: EdgeInsets.zero,
                  glowColor: summary.accentColor.withValues(alpha: 0.30),
                  child: Center(
                    child: Icon(
                      summary.icon,
                      size: 18,
                      color: summary.accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // نام سیستم و توضیح وضعیت
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        summary.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Vazirmatn',
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary.secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Vazirmatn',
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // کپسول پلاک مقدار اصلی
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: summary.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: summary.accentColor.withValues(alpha: 0.28),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    summary.primary,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Vazirmatn',
                      color: summary.accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // فلش راهنما
                Icon(
                  CupertinoIcons.chevron_left,
                  size: 14,
                  color: colors.textSecondary.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


