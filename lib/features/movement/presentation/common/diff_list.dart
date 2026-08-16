import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// انواع تغییرات در لیست تفاوت‌ها (Diff)
enum MovementDiffKind {
  moved,
  shortened,
  replaced,
  added,
  removed,
  locked,
}

/// مدل دادهٔ یک تغییر در لیست تفاوت‌ها
class MovementDiffItem {
  const MovementDiffItem({
    required this.id,
    required this.kind,
    required this.beforeText,
    required this.afterText,
    required this.reason,
    this.isSelected = true,
    this.isLocked = false,
  });

  final String id;
  final MovementDiffKind kind;
  final String beforeText;
  final String afterText;
  final String reason;
  final bool isSelected;
  final bool isLocked;

  MovementDiffItem copyWith({
    String? id,
    MovementDiffKind? kind,
    String? beforeText,
    String? afterText,
    String? reason,
    bool? isSelected,
    bool? isLocked,
  }) {
    return MovementDiffItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      beforeText: beforeText ?? this.beforeText,
      afterText: afterText ?? this.afterText,
      reason: reason ?? this.reason,
      isSelected: isSelected ?? this.isSelected,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

/// ویجت نمایش لیست تفاوت‌ها با قفل بودن جلسات انجام‌شده و پشتیبانی از انتخاب گروهی
class DiffList extends StatelessWidget {
  const DiffList({
    super.key,
    required this.items,
    this.isSelectable = true,
    this.onItemToggled,
  });

  final List<MovementDiffItem> items;
  final bool isSelectable;
  final ValueChanged<MovementDiffItem>? onItemToggled;

  IconData _iconForKind(MovementDiffKind kind) {
    switch (kind) {
      case MovementDiffKind.moved:
        return Icons.swap_horiz_rounded;
      case MovementDiffKind.shortened:
        return Icons.timelapse_rounded;
      case MovementDiffKind.replaced:
        return Icons.cached_rounded;
      case MovementDiffKind.added:
        return Icons.add_circle_outline_rounded;
      case MovementDiffKind.removed:
        return Icons.remove_circle_outline_rounded;
      case MovementDiffKind.locked:
        return Icons.lock_outline_rounded;
    }
  }

  Color _colorForKind(BuildContext context, MovementDiffKind kind) {
    final colors = context.colors;
    switch (kind) {
      case MovementDiffKind.moved:
      case MovementDiffKind.shortened:
        return colors.warning;
      case MovementDiffKind.replaced:
        return colors.accent;
      case MovementDiffKind.added:
        return colors.success;
      case MovementDiffKind.removed:
        return colors.error;
      case MovementDiffKind.locked:
        return colors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: RitmoSpacing.sm),
      itemBuilder: (context, index) {
        final item = items[index];
        final effectiveLocked = item.isLocked || item.kind == MovementDiffKind.locked;
        final iconColor = _colorForKind(context, item.kind);

        return Container(
          padding: const EdgeInsets.all(RitmoSpacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(RitmoRadius.card),
            border: Border.all(
              color: colors.border,
              width: RitmoElevation.borderWidthDark,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // چک‌باکس انتخاب (برای موارد قفل، غیرفعال است)
              if (isSelectable) ...[
                SizedBox(
                  width: MovementLayout.kMinTouchTarget,
                  height: MovementLayout.kMinTouchTarget,
                  child: Center(
                    child: Checkbox(
                      value: effectiveLocked ? false : item.isSelected,
                      onChanged: effectiveLocked
                          ? null
                          : (val) {
                              if (onItemToggled != null) {
                                onItemToggled!(
                                  item.copyWith(isSelected: val ?? false),
                                );
                              }
                            },
                      activeColor: colors.primary,
                      checkColor: colors.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: RitmoSpacing.xs),
              ],

              // آیکون نوع تغییر
              Container(
                width: 32.0,
                height: 32.0,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(RitmoRadius.badge),
                ),
                child: Center(
                  child: Icon(
                    _iconForKind(item.kind),
                    size: 18.0,
                    color: iconColor,
                  ),
                ),
              ),

              const SizedBox(width: RitmoSpacing.md),

              // محتوای تغییر (قبل، بعد، دلیل)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (item.beforeText.isNotEmpty) ...[
                          Flexible(
                            child: Text(
                              '${MovementStrings.diffBefore}: ${item.beforeText}',
                              style: RitmoTextStyles.caption(colors.textTertiary)
                                  .copyWith(
                                decoration: TextDecoration.lineThrough,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: RitmoSpacing.xs),
                          Icon(
                            Icons.arrow_left_rounded,
                            size: 16.0,
                            color: colors.textTertiary,
                          ),
                          const SizedBox(width: RitmoSpacing.xs),
                        ],
                        Flexible(
                          child: Text(
                            '${MovementStrings.diffAfter}: ${item.afterText}',
                            style: RitmoTextStyles.label(
                              effectiveLocked
                                  ? colors.textSecondary
                                  : colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '${MovementStrings.diffReason}: ${item.reason}${effectiveLocked ? ' (${MovementStrings.diffLocked})' : ''}',
                      style: RitmoTextStyles.caption(colors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
