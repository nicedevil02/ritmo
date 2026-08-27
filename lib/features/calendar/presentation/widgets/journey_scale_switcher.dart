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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          // ─── 3-Tab Strip ───
          Expanded(
            child: Container(
              height: 36.0 * context.metrics.densityFactor,
              padding: const EdgeInsets.all(3.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151922) : const Color(0xFFE4E9EF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFCBD3DC).withValues(alpha: 0.8),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.35)
                        : const Color(0xFFC7CFDA).withValues(alpha: 0.55),
                    offset: const Offset(0, 1.5),
                    blurRadius: 3,
                  ),
                ],
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
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? const Color(0xFF262C38) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.035)
                                          : Colors.white,
                                      offset: const Offset(-1.5, -1.5),
                                      blurRadius: 4,
                                    ),
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withValues(alpha: 0.45)
                                          : const Color(0xFFBAC3CF).withValues(alpha: 0.65),
                                      offset: const Offset(1.5, 2.5),
                                      blurRadius: 5,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? colors.primary
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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

          const SizedBox(width: 8),

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
          borderRadius: BorderRadius.circular(RitmoRadius.card),
        ),
        color: colors.surfaceElevated,
        elevation: 4,
        offset: const Offset(0, 4),
        itemBuilder: (ctx) => overflowScales
            .map(
              (scale) => PopupMenuItem<JourneyScale>(
                value: scale,
                child: Text(
                  JourneyScaleSwitcher.scaleLabelFa(scale),
                  style: RitmoTextStyles.label(
                    scale == activeScale ? colors.primary : colors.textPrimary,
                  ).copyWith(
                    fontWeight: scale == activeScale
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList(),
        onSelected: onScaleChanged,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          height: 36 * context.metrics.densityFactor,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isActive
                ? colors.primary.withValues(alpha: 0.14)
                : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF232A37)
                    : const Color(0xFFE4E9EF)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? colors.primary.withValues(alpha: 0.45)
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFCBD3DC)),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.3)
                    : const Color(0xFFC7CFDA).withValues(alpha: 0.6),
                offset: const Offset(1, 2),
                blurRadius: 3,
              ),
            ],
          ),
          child: isActive
              ? Center(
                  child: Text(
                    JourneyScaleSwitcher.scaleLabelFa(activeScale),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: colors.primary,
                    ),
                  ),
                )
              : Center(
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
        ),
      ),
    );
  }
}
