import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';

/// Redesigned Apple HIG & Neumorphic Scale Switcher:
/// 3 primary tabs (برنامه · روز · ماه) with tactile convex sliding pill + overflow ⋯ button for week/year.
class JourneyScaleSwitcher extends StatelessWidget {
  const JourneyScaleSwitcher({
    super.key,
    required this.activeScale,
    required this.onScaleChanged,
  });

  final JourneyScale activeScale;
  final ValueChanged<JourneyScale> onScaleChanged;

  static const List<JourneyScale> _primaryScales = [
    JourneyScale.agenda,
    JourneyScale.day,
    JourneyScale.month,
  ];

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
          // ─── 3-Tab Neumorphic Strip ───
          Expanded(
            child: Container(
              height: 38.0 * context.metrics.densityFactor,
              padding: const EdgeInsets.all(3.5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131720) : const Color(0xFFE2E7EE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFCAD2DC).withValues(alpha: 0.9),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.45)
                        : const Color(0xFFB8C2CF).withValues(alpha: 0.55),
                    offset: const Offset(0, 1.5),
                    blurRadius: 3,
                  ),
                  if (!isDark)
                    const BoxShadow(
                      color: Colors.white,
                      offset: Offset(0, -1),
                      blurRadius: 1.5,
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
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onScaleChanged(scale);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: isDark
                                        ? [
                                            const Color(0xFF2E3544),
                                            const Color(0xFF232936),
                                          ]
                                        : [
                                            Colors.white,
                                            const Color(0xFFF7F9FC),
                                          ],
                                  )
                                : null,
                            color: isSelected ? null : Colors.transparent,
                            borderRadius: BorderRadius.circular(12.5),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.white,
                                      offset: const Offset(-1, -1),
                                      blurRadius: 3,
                                    ),
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withValues(alpha: 0.5)
                                          : const Color(0xFFAEB8C6).withValues(alpha: 0.65),
                                      offset: const Offset(1.5, 2.5),
                                      blurRadius: 4.5,
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
                                  : (isDark ? const Color(0xFF8E9BAE) : const Color(0xFF64748B)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          borderRadius: BorderRadius.circular(16),
        ),
        color: colors.surfaceElevated,
        elevation: 6,
        offset: const Offset(0, 6),
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
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList(),
        onSelected: (scale) {
          HapticFeedback.selectionClick();
          onScaleChanged(scale);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 38 * context.metrics.densityFactor,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: isActive
                ? colors.primary.withValues(alpha: 0.15)
                : (isDark ? const Color(0xFF1E2430) : const Color(0xFFE2E7EE)),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isActive
                  ? colors.primary.withValues(alpha: 0.55)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFCAD2DC)),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : const Color(0xFFB8C2CF).withValues(alpha: 0.65),
                offset: const Offset(1, 2),
                blurRadius: 3.5,
              ),
              if (!isDark && !isActive)
                const BoxShadow(
                  color: Colors.white,
                  offset: Offset(-1, -1),
                  blurRadius: 2,
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
                    size: 19,
                    color: isDark
                        ? const Color(0xFF8E9BAE)
                        : const Color(0xFF64748B),
                  ),
                ),
        ),
      ),
    );
  }
}
