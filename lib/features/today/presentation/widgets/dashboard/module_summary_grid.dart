import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_pressable.dart';
import 'package:ritmo/core/widgets/ritmo_adaptive_grid.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/dashboard_module_summary.dart';

class ModuleSummaryGrid extends StatelessWidget {
  const ModuleSummaryGrid({super.key, required this.summaries, required this.onModuleTap});
  final List<DashboardModuleSummary> summaries;
  final void Function(String moduleId) onModuleTap;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final m = context.metrics;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سیستم‌های فعال',
          style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
        ),
        SizedBox(height: m.spaceMd),
        RitmoAdaptiveGrid(
          minTileWidth: 140,
          spacing: m.spaceSm,
          maxColumns: 2,
          children: [
            for (final summary in summaries)
              SizedBox(
                height: (118.0 * context.textScale * m.densityFactor).clamp(118.0, 175.0),
                child: _ModuleSummaryCard(
                  summary: summary,
                  onTap: () => onModuleTap(summary.moduleId),
                  isDark: isDark,
                  colors: colors,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ModuleSummaryCard extends StatelessWidget {

  const _ModuleSummaryCard({
    required this.summary,
    required this.onTap,
    required this.isDark,
    required this.colors,
  });
  final DashboardModuleSummary summary;
  final VoidCallback onTap;
  final bool isDark;
  final RitmoColors colors;

  @override
  Widget build(BuildContext context) {
    if (summary.backgroundImage != null) {
      return _ImageCard(
        summary: summary,
        onTap: onTap,
        isDark: isDark,
        colors: colors,
      );
    }
    return _PlainCard(
      summary: summary,
      onTap: onTap,
      isDark: isDark,
      colors: colors,
    );
  }
}

// ─── کارت با تصویر پس‌زمینه ────────────────────────────────────────────────
class _ImageCard extends StatelessWidget {

  const _ImageCard({
    required this.summary,
    required this.onTap,
    required this.isDark,
    required this.colors,
  });
  final DashboardModuleSummary summary;
  final VoidCallback onTap;
  final bool isDark;
  final RitmoColors colors;

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    return RitmoPressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(m.radiusCard),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── تصویر پس‌زمینه ──
            Image.asset(
              summary.backgroundImage!,
              cacheWidth: 400,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      summary.accentColor.withValues(alpha: 0.3),
                      summary.accentColor.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
            ),

            // ── پوشش گرادیان کلی ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.45, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: isDark ? 0.20 : 0.08),
                    Colors.transparent,
                    Colors.black.withValues(alpha: isDark ? 0.40 : 0.25),
                  ],
                ),
              ),
            ),

            // ── آیکون و عنوان بالا ──
            Positioned(
              top: m.spaceSm,
              right: m.spaceSm,
              left: m.spaceSm,
              child: Row(
                children: [
                  Container(
                    height: m.iconLg,
                    width: m.iconLg,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(m.radiusField),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(summary.icon, size: m.iconSm, color: Colors.white),
                  ),
                  SizedBox(width: m.spaceXs),
                  Expanded(
                    child: Text(
                      summary.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RitmoTextStyles.caption(Colors.white).copyWith(
                        fontWeight: FontWeight.w600,
                        shadows: const [
                          Shadow(blurRadius: 4, color: Colors.black45),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── قسمت شیشه‌ای تار در زیر کارت ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 54 * m.densityFactor,
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(m.radiusCard),
                  bottomRight: Radius.circular(m.radiusCard),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: m.spaceSm, vertical: m.spaceXs),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.35 : 0.45),
                      border: Border(
                        top: BorderSide(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                          width: 0.8,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          summary.primary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RitmoTextStyles.cardTitle(
                            isDark ? Colors.white : Colors.black87,
                          ).copyWith(
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          summary.secondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RitmoTextStyles.badge(
                            isDark ? Colors.white70 : Colors.black54,
                          ).copyWith(
                            height: 1.15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── کارت ساده (بدون تصویر) ─────────────────────────────────────────────────
class _PlainCard extends StatelessWidget {

  const _PlainCard({
    required this.summary,
    required this.onTap,
    required this.isDark,
    required this.colors,
  });
  final DashboardModuleSummary summary;
  final VoidCallback onTap;
  final bool isDark;
  final RitmoColors colors;

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    final accentAlpha = isDark ? 0.18 : 0.10;
    final borderAlpha = isDark ? 0.30 : 0.20;

    return RitmoPressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(m.radiusCard),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(m.radiusCard),
              color: isDark
                  ? colors.card.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.70),
              border: Border.all(
                color: summary.accentColor.withValues(alpha: borderAlpha),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  summary.accentColor.withValues(alpha: accentAlpha),
                  (isDark ? colors.card : Colors.white).withValues(alpha: 0.40),
                ],
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: m.spaceSm, vertical: m.spaceSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ردیف آیکون + عنوان
                Row(
                  children: [
                    Container(
                      height: m.iconLg, width: m.iconLg,
                      decoration: BoxDecoration(
                        color: summary.accentColor.withValues(alpha: isDark ? 0.22 : 0.14),
                        borderRadius: BorderRadius.circular(m.radiusField),
                        border: Border.all(
                          color: summary.accentColor.withValues(alpha: isDark ? 0.40 : 0.30),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(summary.icon, size: m.iconSm, color: summary.accentColor),
                    ),
                    SizedBox(width: m.spaceXs),
                    Expanded(
                      child: Text(
                        summary.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RitmoTextStyles.caption(colors.textPrimary).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                // داده اصلی و فرعی
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      summary.primary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RitmoTextStyles.cardTitle(colors.textPrimary).copyWith(
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: m.spaceXs, vertical: 2),
                      decoration: BoxDecoration(
                        color: summary.accentColor.withValues(alpha: isDark ? 0.14 : 0.08),
                        borderRadius: BorderRadius.circular(m.radiusField),
                      ),
                      child: Text(
                        summary.secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RitmoTextStyles.badge(colors.textSecondary).copyWith(
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
