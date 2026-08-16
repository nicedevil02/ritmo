import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// سربرگ مرکز حرکت — منطبق بر قرارداد طراحی RTL و الگوهای مرکزی Ritmo
class MovementAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MovementAppBar({
    super.key,
    this.title = MovementStrings.centerTitle,
    this.subtitle,
    required this.onProgressPressed,
    required this.onSettingsPressed,
    this.scrollOffset = 0.0,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onProgressPressed;
  final VoidCallback onSettingsPressed;
  final double scrollOffset;

  bool get isCollapsed => scrollOffset >= 24.0;

  @override
  Size get preferredSize => const Size.fromHeight(MovementLayout.kAppBarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      color: colors.background,
      padding: EdgeInsetsDirectional.only(
        top: topPadding,
        start: RitmoSpacing.lg,
        end: RitmoSpacing.lg,
      ),
      height: MovementLayout.kAppBarHeight + topPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // سمت راست در RTL: عنوان صفحه و زیرعنوان متغیر
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: RitmoTextStyles.pageTitle(colors.textPrimary).copyWith(
                      fontSize: hasSubtitle ? 20.0 : 24.0,
                      height: 1.15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasSubtitle) ...[
                  AnimatedOpacity(
                    opacity: isCollapsed ? 0.0 : 1.0,
                    duration: RitmoMotion.effective(
                      context,
                      RitmoMotion.state,
                    ),
                    curve: Curves.easeInOut,
                    child: isCollapsed
                        ? const SizedBox.shrink()
                        : Text(
                            subtitle!,
                            style: RitmoTextStyles.caption(colors.textSecondary).copyWith(
                              height: 1.15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: RitmoSpacing.sm),

          // سمت چپ در RTL: دو دکمهٔ آیکونی با حداقل هدف لمس ۴۸×۴۸
          _AppBarIconButton(
            icon: Icons.insights_rounded,
            tooltip: MovementStrings.progressTitle,
            semanticsLabel: MovementStrings.progressTitle,
            onPressed: () {
              RitmoHapticsPolicy.selection();
              onProgressPressed();
            },
          ),
          const SizedBox(width: RitmoSpacing.xs),
          _AppBarIconButton(
            icon: Icons.settings_rounded,
            tooltip: MovementStrings.settingsTitle,
            semanticsLabel: MovementStrings.settingsTitle,
            onPressed: () {
              RitmoHapticsPolicy.selection();
              onSettingsPressed();
            },
          ),
        ],
      ),
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  const _AppBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final String semanticsLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(RitmoRadius.iconButton),
            child: SizedBox(
              width: MovementLayout.kMinTouchTarget,
              height: MovementLayout.kMinTouchTarget,
              child: Center(
                child: Container(
                  width: MovementLayout.kActivityIconSize,
                  height: MovementLayout.kActivityIconSize,
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    borderRadius: BorderRadius.circular(RitmoRadius.iconButton),
                    border: Border.all(
                      color: colors.border,
                      width: RitmoElevation.borderWidthDark,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 20.0,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
