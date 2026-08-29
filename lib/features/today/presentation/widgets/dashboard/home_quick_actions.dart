import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';

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

/// نوار افقی میان‌برهای پرکاربرد — متصل به سیستم مرجع کارت‌های نئومورفیک ریتمو.
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key, required this.actions});

  final List<HomeQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 98,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        clipBehavior: Clip.none,
        physics: const BouncingScrollPhysics(),
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final action = actions[index];

          return Semantics(
            button: true,
            label: action.label,
            child: RitmoCard.neumorphic(
              onTap: () {
                RitmoHaptics.selection();
                action.onTap();
              },
              borderRadius: BorderRadius.circular(18),
              borderColor: action.highlighted
                  ? action.color.withValues(alpha: isDark ? 0.55 : 0.75)
                  : null,
              borderWidth: action.highlighted ? 1.2 : null,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              enableSpring: true,
              child: SizedBox(
                width: 78,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // شیار فرورفته نئومورفیک آیکون
                    RitmoNeuSurface(
                      height: 38,
                      width: 38,
                      radius: 19,
                      sunken: true,
                      padding: EdgeInsets.zero,
                      glowColor: action.highlighted
                          ? action.color.withValues(alpha: 0.35)
                          : null,
                      child: Center(
                        child: Icon(
                          action.icon,
                          size: 19,
                          color: action.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Vazirmatn',
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

