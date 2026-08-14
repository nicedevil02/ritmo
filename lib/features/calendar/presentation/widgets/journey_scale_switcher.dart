import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';

/// K18 — Redesigned scale switcher: 3 primary tabs (برنامه · روز · ماه)
/// + overflow ⋯ button for week and year.
class JourneyScaleSwitcher extends StatelessWidget {
  const JourneyScaleSwitcher({
    super.key,
    required this.activeScale,
    required this.onScaleChanged,
  });

  final JourneyScale activeScale;
  final ValueChanged<JourneyScale> onScaleChanged;

  // The three primary scales shown inline
  static const List<JourneyScale> _primaryScales = [
    JourneyScale.agenda,
    JourneyScale.day,
    JourneyScale.month,
  ];

  // Overflow scales (week, year)
  static const List<JourneyScale> _overflowScales = [
    JourneyScale.week,
    JourneyScale.year,
  ];

  bool get _isOverflowActive => _overflowScales.contains(activeScale);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          // ─── 3-Tab Strip ───
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(RitmoSpacing.xs),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(RitmoRadius.field),
                border: Border.all(
                  color: colors.borderSubtle,
                ),
              ),
              child: Row(
                children: _primaryScales.map((scale) {
                  final isSelected = !_isOverflowActive && scale == activeScale;
                  final label = _primaryLabelFa(scale);
                  return Expanded(
                    child: Semantics(
                      selected: isSelected,
                      label: 'نمای $label',
                      button: true,
                      child: GestureDetector(
                        onTap: () => onScaleChanged(scale),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: RitmoMotion.state,
                          curve: RitmoMotion.enter,
                          height: 40.0,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.surfaceElevated
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                                RitmoRadius.iconButton),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: colors.overlay.withValues(alpha: 0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    )
                                  ]
                                : null,
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isSelected
                                  ? colors.primary
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // ─── Overflow ⋯ Button ───
          _OverflowScaleButton(
            activeScale: activeScale,
            isActive: _isOverflowActive,
            overflowScales: _overflowScales,
            onScaleChanged: onScaleChanged,
          ),
        ],
      ),
    );
  }

  static String _primaryLabelFa(JourneyScale scale) {
    switch (scale) {
      case JourneyScale.agenda:
        return 'برنامه';
      case JourneyScale.day:
        return 'روز';
      case JourneyScale.month:
        return 'ماه';
      default:
        return '';
    }
  }

  static String scaleLabelFa(JourneyScale scale) {
    switch (scale) {
      case JourneyScale.agenda:
        return 'برنامه';
      case JourneyScale.day:
        return 'روز';
      case JourneyScale.week:
        return 'هفته';
      case JourneyScale.month:
        return 'ماه';
      case JourneyScale.year:
        return 'سال';
    }
  }
}

/// The overflow ⋯ button that shows week / year options in a popup menu.
class _OverflowScaleButton extends StatelessWidget {
  const _OverflowScaleButton({
    required this.activeScale,
    required this.isActive,
    required this.overflowScales,
    required this.onScaleChanged,
  });

  final JourneyScale activeScale;
  final bool isActive;
  final List<JourneyScale> overflowScales;
  final ValueChanged<JourneyScale> onScaleChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: isActive
          ? 'نمای فعال: ${JourneyScaleSwitcher.scaleLabelFa(activeScale)}'
          : 'نماهای بیشتر',
      child: PopupMenuButton<JourneyScale>(
        tooltip: '',
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RitmoRadius.card)),
        color: colors.surfaceElevated,
        elevation: 4,
        offset: const Offset(0, 4),
        itemBuilder: (ctx) => overflowScales
            .map(
              (scale) => PopupMenuItem<JourneyScale>(
                value: scale,
                child: Text(
                  JourneyScaleSwitcher.scaleLabelFa(scale),
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: scale == activeScale
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: scale == activeScale
                        ? colors.primary
                        : colors.textPrimary,
                  ),
                ),
              ),
            )
            .toList(),
        onSelected: onScaleChanged,
        child: AnimatedContainer(
          duration: RitmoMotion.state,
          curve: RitmoMotion.enter,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isActive
                ? colors.primary.withValues(alpha: 0.12)
                : colors.surfaceSubtle,
            borderRadius: BorderRadius.circular(RitmoRadius.field),
            border: Border.all(
              color: isActive
                  ? colors.primary.withValues(alpha: 0.3)
                  : colors.borderSubtle,
            ),
          ),
          child: isActive
              ? Center(
                  child: Text(
                    JourneyScaleSwitcher.scaleLabelFa(activeScale),
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                )
              : Center(
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                ),
        ),
      ),
    );
  }
}
