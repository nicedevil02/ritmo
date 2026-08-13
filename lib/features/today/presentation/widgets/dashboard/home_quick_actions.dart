import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_pressable.dart';

/// یک میان‌بر تکی در نوار «اقدام سریع» صفحهٔ خانه.
@immutable
class HomeQuickAction {
  const HomeQuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.highlighted = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  /// میان‌بر پیشنهادی لحظه (مثل ارزیابی صبحگاهی) با حاشیهٔ رنگی متمایز می‌شود.
  final bool highlighted;
}

/// نوار افقی میان‌برهای پرکاربرد — کارهای روزمره با یک لمس، بدون ورود به منو.
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key, required this.actions});

  final List<HomeQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.none,
        physics: const BouncingScrollPhysics(),
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: RitmoSpacing.sm),
        itemBuilder: (context, index) {
          final action = actions[index];

          return RitmoPressable(
            onTap: action.onTap,
            semanticLabel: action.label,
            child: Container(
              width: 84,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(RitmoRadius.card),
                color: isDark
                    ? colors.card.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.68),
                border: Border.all(
                  color: action.highlighted
                      ? action.color.withValues(alpha: 0.45)
                      : colors.border.withValues(alpha: 0.7),
                ),
                boxShadow:
                    isDark ? RitmoElevation.none : RitmoElevation.cardLight,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 38,
                    width: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          action.color.withValues(alpha: isDark ? 0.30 : 0.18),
                          action.color.withValues(alpha: isDark ? 0.12 : 0.08),
                        ],
                      ),
                      border: Border.all(
                        color: action.color.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Icon(action.icon, size: 18, color: action.color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
