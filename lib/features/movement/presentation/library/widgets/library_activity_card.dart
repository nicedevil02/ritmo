import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';

/// کارت گونهٔ فعالیت در کتابخانه (LibraryActivityCard)
class LibraryActivityCard extends StatelessWidget {
  const LibraryActivityCard({
    super.key,
    required this.activityKind,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final MovementActivityKind activityKind;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'directions_walk':
        return Icons.directions_walk_rounded;
      case 'directions_run':
        return Icons.directions_run_rounded;
      case 'directions_bike':
        return Icons.directions_bike_rounded;
      case 'pool':
        return Icons.pool_rounded;
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'hiking':
        return Icons.hiking_rounded;
      case 'self_improvement':
        return Icons.self_improvement_rounded;
      case 'sports_soccer':
        return Icons.sports_soccer_rounded;
      default:
        return Icons.sports_rounded;
    }
  }

  String _getMetricLabel(String metric) {
    switch (metric) {
      case 'duration':
        return 'مدت‌زمان';
      case 'distance':
        return 'مسافت';
      case 'volume':
        return 'حجم و تکرار';
      case 'laps':
        return 'طول و دور';
      case 'elevation':
        return 'ارتفاع و پیمایش';
      case 'count':
        return 'شمارش';
      default:
        return 'زمان‌آزاد';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      margin: const EdgeInsets.only(bottom: MovementLayout.kCardSpacing),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(RitmoSpacing.md),
            child: Row(
              children: [
                // آیکون گونه
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: sportsColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(RitmoRadius.card),
                  ),
                  child: Icon(
                    _getIconData(activityKind.icon),
                    color: sportsColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: RitmoSpacing.md),

                // نام و متریک اصلی
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            activityKind.nameFa,
                            style: RitmoTextStyles.cardTitle(
                              colors.textPrimary,
                            ),
                          ),
                          if (activityKind.isCustom) ...[
                            const SizedBox(width: RitmoSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: sportsColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  RitmoRadius.badge,
                                ),
                              ),
                              child: Text(
                                'سفارشی',
                                style: RitmoTextStyles.caption(
                                  sportsColor,
                                ).copyWith(fontSize: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'شاخص اصلی: ${_getMetricLabel(activityKind.primaryMetric)}',
                        style: RitmoTextStyles.caption(colors.textSecondary),
                      ),
                    ],
                  ),
                ),

                // دکمهٔ نشان‌کردن / علاقه‌مندی
                IconButton(
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    activityKind.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: activityKind.isFavorite
                        ? Colors.amber
                        : colors.textTertiary,
                    size: 24,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
