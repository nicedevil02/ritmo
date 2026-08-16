import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/presentation/common/movement_icons.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// تایل نمایش هر فعالیت ورزشی در ۲ ستون (یا حالت جمع‌وجور) با حداقل ارتفاع ۷۲ پیکسل
class ActivityKindTile extends StatelessWidget {
  const ActivityKindTile({
    super.key,
    required this.activityKind,
    required this.onTap,
    this.onFavoriteToggle,
    this.isCompact = false,
  });

  final MovementActivityKind activityKind;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteToggle;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Semantics(
      label:
          '${activityKind.nameFa}، شاخص اصلی: ${activityKind.primaryMetric}${activityKind.isFavorite ? '، برگزیده' : ''}',
      button: true,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: MovementLayout.kTileMinHeight,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: RitmoSpacing.md,
              vertical: RitmoSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              border: Border.all(color: colors.border, width: 1.0),
            ),
            child: Row(
              children: [
                // آیکون خانواده فعالیت
                Container(
                  width: MovementLayout.kIconContainerSize,
                  height: MovementLayout.kIconContainerSize,
                  decoration: BoxDecoration(
                    color: sportsColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(RitmoRadius.iconButton),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    MovementIcons.fromKey(activityKind.icon),
                    color: sportsColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: RitmoSpacing.md),

                // نام فارسی و شاخص اصلی
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activityKind.nameFa,
                        style: RitmoTextStyles.cardTitle(colors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'شاخص: ${activityKind.primaryMetric}',
                        style: RitmoTextStyles.caption(colors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // ستارهٔ علاقه‌مندی
                if (onFavoriteToggle != null)
                  IconButton(
                    icon: Icon(
                      activityKind.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: activityKind.isFavorite
                          ? const Color(0xFFFFB800)
                          : colors.textSecondary.withValues(alpha: 0.4),
                      size: 22,
                    ),
                    onPressed: onFavoriteToggle,
                    tooltip: activityKind.isFavorite
                        ? MovementStrings.favoriteRemove
                        : MovementStrings.favoriteAdd,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
