import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// نوار ناوبری هفته با دکمه‌های هفتهٔ قبل/بعد، عنوان بازه، چیپ بازگشت به هفتهٔ جاری و پشتیبانی از Swipe
class WeekNavigatorBar extends StatefulWidget {
  const WeekNavigatorBar({
    super.key,
    required this.rangeTitle,
    required this.isCurrentWeek,
    required this.onPreviousWeek,
    required this.onNextWeek,
    this.onCurrentWeekPressed,
  });

  final String rangeTitle;
  final bool isCurrentWeek;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback? onCurrentWeekPressed;

  @override
  State<WeekNavigatorBar> createState() => _WeekNavigatorBarState();
}

class _WeekNavigatorBarState extends State<WeekNavigatorBar> {
  double _cumulativeDrag = 0.0;

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    _cumulativeDrag += details.primaryDelta ?? 0.0;
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    // در چیدمان RTL: سوایپ به راست (سرعت یا جابه‌جایی مثبت) = هفتهٔ قبل، سوایپ به چپ = هفتهٔ بعد
    if (velocity > 100 || _cumulativeDrag > 30) {
      widget.onPreviousWeek();
    } else if (velocity < -100 || _cumulativeDrag < -30) {
      widget.onNextWeek();
    }
    _cumulativeDrag = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onHorizontalDragUpdate: _handleHorizontalDragUpdate,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: MovementLayout.kWeekNavigatorHeight,
        padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // دکمهٔ هفتهٔ قبل (در RTL جهت فلش به راست است)
            Semantics(
              button: true,
              label: MovementStrings.navPreviousWeek,
              child: Tooltip(
                message: MovementStrings.navPreviousWeek,
                child: InkWell(
                  onTap: widget.onPreviousWeek,
                  borderRadius: BorderRadius.circular(RitmoRadius.iconButton),
                  child: const SizedBox(
                    width: MovementLayout.kMinTouchTarget,
                    height: MovementLayout.kMinTouchTarget,
                    child: Center(
                      child: Icon(Icons.chevron_right_rounded, size: 24.0),
                    ),
                  ),
                ),
              ),
            ),

            // عنوان بازهٔ هفته و چیپ اختیاری «این هفته»
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Semantics(
                      label: widget.rangeTitle,
                      child: AnimatedSwitcher(
                        duration: RitmoMotion.effective(
                          context,
                          RitmoMotion.state,
                        ),
                        child: Text(
                          widget.rangeTitle,
                          key: ValueKey<String>(widget.rangeTitle),
                          style: RitmoTextStyles.titleMedium(
                            colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  if (!widget.isCurrentWeek &&
                      widget.onCurrentWeekPressed != null) ...[
                    const SizedBox(width: RitmoSpacing.sm),
                    Semantics(
                      button: true,
                      label: MovementStrings.navReturnToCurrentWeek,
                      child: Tooltip(
                        message: MovementStrings.navReturnToCurrentWeek,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onCurrentWeekPressed,
                            borderRadius: BorderRadius.circular(
                              RitmoRadius.pill,
                            ),
                            child: Container(
                              constraints: const BoxConstraints(
                                minHeight: MovementLayout.kMinTouchTarget,
                                minWidth: MovementLayout.kMinTouchTarget,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: RitmoSpacing.md,
                                vertical: RitmoSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                borderRadius: BorderRadius.circular(
                                  RitmoRadius.pill,
                                ),
                                border: Border.all(
                                  color: colors.border,
                                  width: RitmoElevation.borderWidthDark,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  MovementStrings.centerThisWeek,
                                  style: RitmoTextStyles.badge(colors.primary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // دکمهٔ هفتهٔ بعد (در RTL جهت فلش به چپ است)
            Semantics(
              button: true,
              label: MovementStrings.navNextWeek,
              child: Tooltip(
                message: MovementStrings.navNextWeek,
                child: InkWell(
                  onTap: widget.onNextWeek,
                  borderRadius: BorderRadius.circular(RitmoRadius.iconButton),
                  child: const SizedBox(
                    width: MovementLayout.kMinTouchTarget,
                    height: MovementLayout.kMinTouchTarget,
                    child: Center(
                      child: Icon(Icons.chevron_left_rounded, size: 24.0),
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
