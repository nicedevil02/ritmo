import 'package:flutter/cupertino.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/core/widgets/ritmo_adaptive_grid.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/dashboard_module_summary.dart';

/// گرید سیستم‌های فعال متصل به سامانه مرجع کارت‌های نئومورفیک ریتمو.
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
    final m = context.metrics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سیستم‌های فعال',
          style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
        ),
        SizedBox(height: m.spaceMd),
        RitmoAdaptiveGrid(
          minTileWidth: 145,
          spacing: 12,
          maxColumns: 2,
          children: [
            for (final summary in summaries)
              SizedBox(
                height: (124.0 * context.textScale * m.densityFactor).clamp(124.0, 180.0),
                child: _ModuleSummaryCard(
                  summary: summary,
                  onTap: () => onModuleTap(summary.moduleId),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// کارت مینیمال نئومورفیک سیستم‌های فعال با عمق ۳ بعدی، شیار فرورفته آیکون و فیزیک فنری.
class _ModuleSummaryCard extends StatelessWidget {
  const _ModuleSummaryCard({
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
      child: RitmoCard.neumorphic(
        onTap: () {
          RitmoHaptics.selection();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enableSpring: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── ردیف سرعنوان: شیار فرورفته نئومورفیک آیکون + عنوان + فلش ──
            Row(
              children: [
                RitmoNeuSurface(
                  height: 34,
                  width: 34,
                  radius: 17,
                  sunken: true,
                  padding: EdgeInsets.zero,
                  glowColor: summary.accentColor.withValues(alpha: 0.35),
                  child: Center(
                    child: Icon(
                      summary.icon,
                      size: 16,
                      color: summary.accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Vazirmatn',
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_left,
                  size: 12,
                  color: colors.textSecondary.withValues(alpha: 0.5),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── بخش داده و آمار اصلی و فرعی ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  summary.primary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Vazirmatn',
                    color: colors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 4.5,
                      height: 4.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: summary.accentColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        summary.secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Vazirmatn',
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

